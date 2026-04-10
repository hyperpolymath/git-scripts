# Git Scripts UI (ReScript + TEA)

This is a ReScript-TEA UI for `git-scripts` with:

- Cadre-style typed route module (`src/CadreTeaRouter.res`)
- Hybrid Automation Router API wiring (`/api/har/*`)
- Allowlisted script execution API (`/api/scripts/run`)

## Run

```bash
cd /var/mnt/eclipse/repos/git-scripts/ui
npm i
npm run dev
```

`npm run dev` starts:

- API server on `http://127.0.0.1:4077` (`server.mjs`)
- ReScript compiler watch
- Vite dev UI on `http://127.0.0.1:5174`

## Build

```bash
cd /var/mnt/eclipse/repos/git-scripts/ui
rm -f lib/rescript.lock
npm run build
```

## API

- `GET /api/health`
- `GET /api/scripts`
- `POST /api/scripts/run` body: `{ "action": "<allowlisted-action>" }`
- `GET /api/har/status`
- `GET /api/har/targets`
- `POST /api/har/route` body: `{ "category": "filesystem", "target": "optional" }`

## HAR command resolution

The server resolves HAR in this order:

1. `HAR_CMD` environment variable (if set)
2. `hybrid-automation-router/target/release/har`
3. `hybrid-automation-router/target/debug/har`
4. `har` on `PATH`
5. `cargo run -q -p har-cli --` in `hybrid-automation-router`

