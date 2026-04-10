@val external jsonStringify: 'a => string = "JSON.stringify"

let decodeRawString = (body: string): result<string, string> => Ok(body)

let makeJsonBody = (pairs: array<(string, string)>): string => {
  let dict = Js.Dict.empty()
  Array.forEach(pairs, ((key, value)) => Js.Dict.set(dict, key, value))
  jsonStringify(dict)
}

let fetchStatus = (toMsg: result<string, Tea.Http.error> => 'msg): Tea.Cmd.t<'msg> => {
  Tea.Http.getString(~url="/api/har/status", ~toMsg)
}

let fetchTargets = (toMsg: result<string, Tea.Http.error> => 'msg): Tea.Cmd.t<'msg> => {
  Tea.Http.getString(~url="/api/har/targets", ~toMsg)
}

let routeCategory = (
  ~category: string,
  ~target: option<string>,
  ~toMsg: result<string, Tea.Http.error> => 'msg,
): Tea.Cmd.t<'msg> => {
  let trimmedTarget = target->Option.map(String.trim)
  let body =
    switch trimmedTarget {
    | Some(value) if value != "" => makeJsonBody([("category", category), ("target", value)])
    | _ => makeJsonBody([("category", category)])
    }

  Tea.Http.postJson(
    ~url="/api/har/route",
    ~body,
    ~decoder=decodeRawString,
    ~toMsg,
  )
}

let runScript = (~action: string, ~toMsg: result<string, Tea.Http.error> => 'msg): Tea.Cmd.t<'msg> => {
  let body = makeJsonBody([("action", action)])
  Tea.Http.postJson(
    ~url="/api/scripts/run",
    ~body,
    ~decoder=decodeRawString,
    ~toMsg,
  )
}
