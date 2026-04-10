import {spawn, spawnSync} from "node:child_process"
import {existsSync} from "node:fs"
import {createServer} from "node:http"
import {dirname, resolve} from "node:path"
import {fileURLToPath} from "node:url"

const THIS_DIR = dirname(fileURLToPath(import.meta.url))
const REPO_DIR = resolve(THIS_DIR, "..")
const HAR_REPO = resolve(REPO_DIR, "../hybrid-automation-router")
const PORT = Number(process.env.GIT_SCRIPTS_UI_API_PORT || "4077")
const TIMEOUT_MS = Number(process.env.GIT_SCRIPTS_UI_TIMEOUT_MS || "300000")
const MAX_CAPTURE_BYTES = Number(process.env.GIT_SCRIPTS_UI_MAX_CAPTURE_BYTES || "2000000")

const SCRIPT_ACTIONS = {
  wiki_audit: {
    label: "Wiki Audit",
    command: ["bash", resolve(REPO_DIR, "scripts/wiki-audit.sh")],
  },
  project_tabs_audit: {
    label: "Project Tabs Audit",
    command: ["bash", resolve(REPO_DIR, "scripts/project-tabs-audit.sh")],
  },
  branch_protection_dry_run: {
    label: "Branch Protection (dry-run)",
    command: ["bash", resolve(REPO_DIR, "scripts/branch-protection-apply.sh"), "--dry-run"],
  },
  md_to_adoc: {
    label: "MD to ADOC",
    command: ["bash", resolve(REPO_DIR, "scripts/md_to_adoc_converter.sh")],
  },
  standardize_readmes: {
    label: "Standardize READMEs",
    command: ["bash", resolve(REPO_DIR, "scripts/standardize_readmes.sh")],
  },
  audit_scripts: {
    label: "Audit Scripts",
    command: ["bash", resolve(REPO_DIR, "scripts/audit_script.sh")],
  },
  verify: {
    label: "Verify",
    command: ["bash", resolve(REPO_DIR, "scripts/verify.sh")],
  },
  gh_cli: {
    label: "Use GH CLI",
    command: ["bash", resolve(REPO_DIR, "scripts/USE-GH-CLI.sh")],
  },
}

const JSON_HEADERS = {
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
}

function sendJson(res, statusCode, payload) {
  res.writeHead(statusCode, JSON_HEADERS)
  res.end(JSON.stringify(payload, null, 2))
}

function readBody(req) {
  return new Promise((resolveBody, rejectBody) => {
    const chunks = []
    req.on("data", chunk => chunks.push(chunk))
    req.on("end", () => {
      const raw = Buffer.concat(chunks).toString("utf8").trim()
      if (!raw) {
        resolveBody({})
        return
      }
      try {
        resolveBody(JSON.parse(raw))
      } catch (error) {
        rejectBody(new Error(`Invalid JSON body: ${error.message}`))
      }
    })
    req.on("error", rejectBody)
  })
}

function appendBounded(existing, next, maxBytes) {
  if (existing.length >= maxBytes) {
    return [existing, true]
  }
  const combined = existing + next
  if (combined.length <= maxBytes) {
    return [combined, false]
  }
  return [combined.slice(0, maxBytes), true]
}

function runCommand(command, args, {cwd = REPO_DIR, timeoutMs = TIMEOUT_MS} = {}) {
  return new Promise(resolveResult => {
    const startedAt = Date.now()
    let stdout = ""
    let stderr = ""
    let truncated = false
    let timedOut = false

    const child = spawn(command, args, {
      cwd,
      env: process.env,
    })

    const timer = setTimeout(() => {
      timedOut = true
      child.kill("SIGTERM")
      setTimeout(() => {
        if (!child.killed) {
          child.kill("SIGKILL")
        }
      }, 4000)
    }, timeoutMs)

    child.stdout.on("data", chunk => {
      const [nextValue, wasTruncated] = appendBounded(stdout, chunk.toString("utf8"), MAX_CAPTURE_BYTES)
      stdout = nextValue
      truncated = truncated || wasTruncated
    })

    child.stderr.on("data", chunk => {
      const [nextValue, wasTruncated] = appendBounded(stderr, chunk.toString("utf8"), MAX_CAPTURE_BYTES)
      stderr = nextValue
      truncated = truncated || wasTruncated
    })

    child.on("error", error => {
      clearTimeout(timer)
      resolveResult({
        ok: false,
        code: 127,
        signal: null,
        timedOut,
        durationMs: Date.now() - startedAt,
        truncated,
        stdout,
        stderr: stderr + `\n${error.message}`,
      })
    })

    child.on("close", (code, signal) => {
      clearTimeout(timer)
      const exitCode = code ?? 1
      resolveResult({
        ok: exitCode === 0 && !timedOut,
        code: exitCode,
        signal,
        timedOut,
        durationMs: Date.now() - startedAt,
        truncated,
        stdout,
        stderr,
      })
    })
  })
}

function findHarCommand() {
  if (process.env.HAR_CMD && process.env.HAR_CMD.trim() !== "") {
    const parts = process.env.HAR_CMD.trim().split(/\s+/)
    return {command: parts[0], args: parts.slice(1), cwd: REPO_DIR, source: "HAR_CMD"}
  }

  const releasePath = resolve(HAR_REPO, "target/release/har")
  if (existsSync(releasePath)) {
    return {command: releasePath, args: [], cwd: HAR_REPO, source: "target/release/har"}
  }

  const debugPath = resolve(HAR_REPO, "target/debug/har")
  if (existsSync(debugPath)) {
    return {command: debugPath, args: [], cwd: HAR_REPO, source: "target/debug/har"}
  }

  const whichHar = spawnSync("bash", ["-lc", "command -v har"], {encoding: "utf8"})
  if (whichHar.status === 0 && whichHar.stdout.trim() !== "") {
    return {command: whichHar.stdout.trim(), args: [], cwd: REPO_DIR, source: "PATH:har"}
  }

  return {
    command: "cargo",
    args: ["run", "-q", "-p", "har-cli", "--"],
    cwd: HAR_REPO,
    source: "cargo run -p har-cli",
  }
}

async function runHar(extraArgs) {
  const resolved = findHarCommand()
  const args = [...resolved.args, ...extraArgs]
  const outcome = await runCommand(resolved.command, args, {cwd: resolved.cwd})
  return {
    ...outcome,
    command: [resolved.command, ...args],
    source: resolved.source,
    output: `${outcome.stdout}${outcome.stderr ? `\n${outcome.stderr}` : ""}`.trim(),
  }
}

function listActions() {
  return Object.entries(SCRIPT_ACTIONS).map(([id, value]) => ({
    id,
    label: value.label,
    command: value.command,
  }))
}

async function handleRequest(req, res) {
  if (!req.url) {
    sendJson(res, 400, {ok: false, error: "Missing URL"})
    return
  }

  if (req.method === "OPTIONS") {
    res.writeHead(204, JSON_HEADERS)
    res.end("")
    return
  }

  const url = new URL(req.url, "http://127.0.0.1")

  if (req.method === "GET" && url.pathname === "/api/health") {
    sendJson(res, 200, {ok: true, service: "git-scripts-ui-api"})
    return
  }

  if (req.method === "GET" && url.pathname === "/api/scripts") {
    sendJson(res, 200, {ok: true, actions: listActions()})
    return
  }

  if (req.method === "GET" && url.pathname === "/api/har/status") {
    const result = await runHar(["status"])
    sendJson(res, result.ok ? 200 : 502, {
      ok: result.ok,
      command: result.command,
      source: result.source,
      durationMs: result.durationMs,
      code: result.code,
      signal: result.signal,
      timedOut: result.timedOut,
      truncated: result.truncated,
      stdout: result.stdout,
      stderr: result.stderr,
      output: result.output,
    })
    return
  }

  if (req.method === "GET" && url.pathname === "/api/har/targets") {
    const result = await runHar(["targets"])
    sendJson(res, result.ok ? 200 : 502, {
      ok: result.ok,
      command: result.command,
      source: result.source,
      durationMs: result.durationMs,
      code: result.code,
      signal: result.signal,
      timedOut: result.timedOut,
      truncated: result.truncated,
      stdout: result.stdout,
      stderr: result.stderr,
      output: result.output,
    })
    return
  }

  if (req.method === "POST" && url.pathname === "/api/har/route") {
    const body = await readBody(req)
    const category = typeof body.category === "string" ? body.category.trim() : ""
    const target = typeof body.target === "string" ? body.target.trim() : ""

    if (!category) {
      sendJson(res, 400, {ok: false, error: "category is required"})
      return
    }

    const args = ["route", category]
    if (target) {
      args.push("--target", target)
    }

    const result = await runHar(args)
    sendJson(res, result.ok ? 200 : 502, {
      ok: result.ok,
      request: {category, target: target || null},
      command: result.command,
      source: result.source,
      durationMs: result.durationMs,
      code: result.code,
      signal: result.signal,
      timedOut: result.timedOut,
      truncated: result.truncated,
      stdout: result.stdout,
      stderr: result.stderr,
      output: result.output,
    })
    return
  }

  if (req.method === "POST" && url.pathname === "/api/scripts/run") {
    const body = await readBody(req)
    const action = typeof body.action === "string" ? body.action : ""
    const selected = SCRIPT_ACTIONS[action]

    if (!selected) {
      sendJson(res, 400, {
        ok: false,
        error: "Unknown action",
        availableActions: Object.keys(SCRIPT_ACTIONS),
      })
      return
    }

    const [command, ...args] = selected.command
    const result = await runCommand(command, args, {cwd: REPO_DIR})
    sendJson(res, result.ok ? 200 : 502, {
      ok: result.ok,
      action,
      label: selected.label,
      command: selected.command,
      durationMs: result.durationMs,
      code: result.code,
      signal: result.signal,
      timedOut: result.timedOut,
      truncated: result.truncated,
      stdout: result.stdout,
      stderr: result.stderr,
      output: `${result.stdout}${result.stderr ? `\n${result.stderr}` : ""}`.trim(),
    })
    return
  }

  sendJson(res, 404, {ok: false, error: "Not found"})
}

const server = createServer((req, res) => {
  handleRequest(req, res).catch(error => {
    sendJson(res, 500, {
      ok: false,
      error: error.message,
      stack: error.stack,
    })
  })
})

server.listen(PORT, "127.0.0.1", () => {
  console.log(`[git-scripts-ui-api] listening on http://127.0.0.1:${PORT}`)
})

