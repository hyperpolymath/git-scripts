type apiState =
  | Idle
  | Loading
  | Loaded(string)
  | Failed(string)

type scriptAction = {
  id: string,
  label: string,
  detail: string,
}

type model = {
  route: CadreTeaRouter.route,
  harCategory: string,
  harTarget: string,
  harStatus: apiState,
  harTargets: apiState,
  harRoute: apiState,
  scriptRun: apiState,
}

type msg =
  | SyncRoute
  | Navigate(CadreTeaRouter.route)
  | SetHarCategory(string)
  | SetHarTarget(string)
  | FetchHarStatus
  | FetchHarTargets
  | RunHarRoute
  | RunScript(string)
  | HarStatusResult(result<string, Tea.Http.error>)
  | HarTargetsResult(result<string, Tea.Http.error>)
  | HarRouteResult(result<string, Tea.Http.error>)
  | ScriptResult(result<string, Tea.Http.error>)

let scriptActions: array<scriptAction> = [
  {
    id: "wiki_audit",
    label: "Wiki Audit",
    detail: "Run scripts/wiki-audit.sh",
  },
  {
    id: "project_tabs_audit",
    label: "Project Tabs Audit",
    detail: "Run scripts/project-tabs-audit.sh",
  },
  {
    id: "branch_protection_dry_run",
    label: "Branch Protection (dry-run)",
    detail: "Run scripts/branch-protection-apply.sh --dry-run",
  },
  {
    id: "md_to_adoc",
    label: "MD to ADOC",
    detail: "Run scripts/md_to_adoc_converter.sh",
  },
  {
    id: "standardize_readmes",
    label: "Standardize READMEs",
    detail: "Run scripts/standardize_readmes.sh",
  },
  {
    id: "audit_scripts",
    label: "Audit Scripts",
    detail: "Run scripts/audit_script.sh",
  },
  {
    id: "verify",
    label: "Verify",
    detail: "Run scripts/verify.sh",
  },
  {
    id: "gh_cli",
    label: "Use GH CLI",
    detail: "Run scripts/USE-GH-CLI.sh",
  },
]

let init = (): (model, Tea.Cmd.t<msg>) => {
  let route = CadreTeaRouter.currentRoute()
  (
    {
      route,
      harCategory: "filesystem",
      harTarget: "",
      harStatus: Idle,
      harTargets: Idle,
      harRoute: Idle,
      scriptRun: Idle,
    },
    Tea.Cmd.batch(list{Tea.Cmd.msg(FetchHarStatus), Tea.Cmd.msg(FetchHarTargets)}),
  )
}

let failWithHttpError = (httpError: Tea.Http.error): apiState => Failed(Tea.Http.errorToString(httpError))

let update = (model: model, msg: msg): (model, Tea.Cmd.t<msg>) => {
  switch msg {
  | SyncRoute => ({...model, route: CadreTeaRouter.currentRoute()}, Tea.Cmd.none)
  | Navigate(route) => {
      if route == model.route {
        (model, Tea.Cmd.none)
      } else {
        ({...model, route}, CadreTeaRouter.navigate(route, SyncRoute))
      }
    }
  | SetHarCategory(category) => ({...model, harCategory: category}, Tea.Cmd.none)
  | SetHarTarget(target) => ({...model, harTarget: target}, Tea.Cmd.none)
  | FetchHarStatus =>
    (
      {...model, harStatus: Loading},
      HarApi.fetchStatus(result => HarStatusResult(result)),
    )
  | FetchHarTargets =>
    (
      {...model, harTargets: Loading},
      HarApi.fetchTargets(result => HarTargetsResult(result)),
    )
  | RunHarRoute => {
      let category = model.harCategory->String.trim
      if category == "" {
        ({...model, harRoute: Failed("Category is required.")}, Tea.Cmd.none)
      } else {
        let target =
          switch model.harTarget->String.trim {
          | "" => None
          | value => Some(value)
          }
        (
          {...model, harRoute: Loading},
          HarApi.routeCategory(~category, ~target, ~toMsg=result => HarRouteResult(result)),
        )
      }
    }
  | RunScript(action) => (
      {...model, scriptRun: Loading},
      HarApi.runScript(~action, ~toMsg=result => ScriptResult(result)),
    )
  | HarStatusResult(result) => {
      switch result {
      | Ok(body) => ({...model, harStatus: Loaded(body)}, Tea.Cmd.none)
      | Error(httpError) => ({...model, harStatus: failWithHttpError(httpError)}, Tea.Cmd.none)
      }
    }
  | HarTargetsResult(result) => {
      switch result {
      | Ok(body) => ({...model, harTargets: Loaded(body)}, Tea.Cmd.none)
      | Error(httpError) => ({...model, harTargets: failWithHttpError(httpError)}, Tea.Cmd.none)
      }
    }
  | HarRouteResult(result) => {
      switch result {
      | Ok(body) => ({...model, harRoute: Loaded(body)}, Tea.Cmd.none)
      | Error(httpError) => ({...model, harRoute: failWithHttpError(httpError)}, Tea.Cmd.none)
      }
    }
  | ScriptResult(result) => {
      switch result {
      | Ok(body) => ({...model, scriptRun: Loaded(body)}, Tea.Cmd.none)
      | Error(httpError) => ({...model, scriptRun: failWithHttpError(httpError)}, Tea.Cmd.none)
      }
    }
  }
}

let viewApiState = (state: apiState): Tea.Html.t<msg> => {
  open Tea.Html
  switch state {
  | Idle => div(list{Attrs.class_("status")}, list{text("Idle.")})
  | Loading => div(list{Attrs.class_("status loading")}, list{text("Running...")})
  | Failed(error) => div(list{Attrs.class_("status err")}, list{text(error)})
  | Loaded(payload) =>
    div(
      list{},
      list{
        div(list{Attrs.class_("status ok")}, list{text("Completed")}),
        pre(list{Attrs.class_("output")}, list{text(payload)}),
      },
    )
  }
}

let viewTab = (activeRoute: CadreTeaRouter.route, route: CadreTeaRouter.route): Tea.Html.t<msg> => {
  open Tea.Html
  let className = if activeRoute == route { "tab active" } else { "tab" }
  button(list{Attrs.class_(className), Events.onClick(Navigate(route))}, list{text(CadreTeaRouter.label(route))})
}

let viewScriptAction = (action: scriptAction): Tea.Html.t<msg> => {
  open Tea.Html
  li(
    list{},
    list{
      div(
        list{Attrs.class_("row")},
        list{
          button(
            list{Attrs.class_("button secondary"), Events.onClick(RunScript(action.id))},
            list{text(action.label)},
          ),
          span(list{Attrs.class_("muted")}, list{text(action.detail)}),
        },
      ),
    },
  )
}

let viewDashboard = (model: model): Tea.Html.t<msg> => {
  open Tea.Html
  fragment(
    list{
      div(
        list{Attrs.class_("panel")},
        list{
          h2(list{}, list{text("Hybrid Automation Router Status")}),
          p(list{Attrs.class_("muted")}, list{text("Live status from HAR CLI.")}),
          div(
            list{Attrs.class_("row")},
            list{
              button(list{Attrs.class_("button"), Events.onClick(FetchHarStatus)}, list{text("Refresh Status")}),
              button(
                list{Attrs.class_("button secondary"), Events.onClick(FetchHarTargets)},
                list{text("Load Targets")},
              ),
            },
          ),
          viewApiState(model.harStatus),
        },
      ),
      div(
        list{Attrs.class_("panel")},
        list{
          h2(list{}, list{text("Current HAR Targets")}),
          p(list{Attrs.class_("muted")}, list{text("Resolved from the active HAR command source.")}),
          viewApiState(model.harTargets),
        },
      ),
      div(
        list{Attrs.class_("panel")},
        list{
          h2(list{}, list{text("Latest Script Output")}),
          p(
            list{Attrs.class_("muted")},
            list{text("Run script actions from Operations tab. Output appears here and in Operations.")},
          ),
          viewApiState(model.scriptRun),
        },
      ),
    },
  )
}

let viewOperations = (model: model): Tea.Html.t<msg> => {
  open Tea.Html
  let actionNodes = scriptActions->Array.map(viewScriptAction)->List.fromArray

  fragment(
    list{
      div(
        list{Attrs.class_("panel")},
        list{
          h2(list{}, list{text("Script Operations")}),
          p(
            list{Attrs.class_("muted")},
            list{text("These actions run allowlisted scripts from git-scripts/scripts.")},
          ),
          ul(list{Attrs.class_("actions")}, actionNodes),
        },
      ),
      div(
        list{Attrs.class_("panel")},
        list{
          h2(list{}, list{text("Operation Result")}),
          viewApiState(model.scriptRun),
        },
      ),
    },
  )
}

let viewHybridRouter = (model: model): Tea.Html.t<msg> => {
  open Tea.Html
  fragment(
    list{
      div(
        list{Attrs.class_("panel")},
        list{
          h2(list{}, list{text("Route A Category")}),
          p(
            list{Attrs.class_("muted")},
            list{text("Send a category to HAR and inspect the routing decision payload.")},
          ),
          div(
            list{Attrs.class_("row")},
            list{
              input(
                list{
                  Attrs.class_("input"),
                  Attrs.placeholder("category, e.g. filesystem"),
                  Attrs.value(model.harCategory),
                  Events.onInput(value => SetHarCategory(value)),
                },
                list{},
              ),
              input(
                list{
                  Attrs.class_("input"),
                  Attrs.placeholder("optional target hint"),
                  Attrs.value(model.harTarget),
                  Events.onInput(value => SetHarTarget(value)),
                },
                list{},
              ),
            },
          ),
          div(
            list{Attrs.class_("row")},
            list{
              button(list{Attrs.class_("button"), Events.onClick(RunHarRoute)}, list{text("Route Event")}),
            },
          ),
          viewApiState(model.harRoute),
        },
      ),
      div(
        list{Attrs.class_("panel")},
        list{
          h2(list{}, list{text("HAR Status Snapshot")}),
          viewApiState(model.harStatus),
        },
      ),
    },
  )
}

let view = (model: model): Tea.Html.t<msg> => {
  open Tea.Html
  div(
    list{Attrs.class_("shell")},
    list{
      header(
        list{},
        list{
          h1(list{Attrs.class_("title")}, list{text("Git Scripts Cadre-TEA Router UI")}),
          p(
            list{Attrs.class_("subtitle")},
            list{
              text(
                "ReScript-TEA control plane with hybrid-automation-router + allowlisted script execution.",
              ),
            },
          ),
        },
      ),
      nav(
        list{Attrs.class_("tabs")},
        list{
          viewTab(model.route, CadreTeaRouter.Dashboard),
          viewTab(model.route, CadreTeaRouter.Operations),
          viewTab(model.route, CadreTeaRouter.HybridRouter),
        },
      ),
      switch model.route {
      | CadreTeaRouter.Dashboard => viewDashboard(model)
      | CadreTeaRouter.Operations => viewOperations(model)
      | CadreTeaRouter.HybridRouter => viewHybridRouter(model)
      },
    },
  )
}

let subscriptions = (_model: model): Tea.Sub.t<msg> => CadreTeaRouter.subscriptions(SyncRoute)

let start = () => {
  Tea.standardProgram(
    ~init,
    ~update,
    ~view,
    ~subscriptions,
    (),
  )
}
