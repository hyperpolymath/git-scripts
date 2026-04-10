type route =
  | Dashboard
  | Operations
  | HybridRouter

let fromPath = (path: string): route => {
  switch path {
  | "/operations" => Operations
  | "/har" => HybridRouter
  | _ => Dashboard
  }
}

let toPath = (route: route): string => {
  switch route {
  | Dashboard => "/"
  | Operations => "/operations"
  | HybridRouter => "/har"
  }
}

let label = (route: route): string => {
  switch route {
  | Dashboard => "Dashboard"
  | Operations => "Operations"
  | HybridRouter => "Hybrid Router"
  }
}

let currentPath = (): string => %raw(`window.location.pathname || "/"`)

let currentRoute = (): route => fromPath(currentPath())

let subscriptions = (msg: 'msg): Tea.Sub.t<'msg> => {
  Tea.Window.onPopState(msg)
}

let navigate = (route: route, syncMsg: 'msg): Tea.Cmd.t<'msg> => {
  Tea.Cmd.call(callbacks => {
    let path = toPath(route)
    let _ = %raw(`window.history.pushState({}, "", path)`)
    callbacks.enqueue(syncMsg)
  })
}

