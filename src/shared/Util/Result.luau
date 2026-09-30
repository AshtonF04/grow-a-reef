local Types = require(script.Parent.Parent.Types)

type Result<T> = Types.Result<T>
type ErrorCode = Types.ErrorCode

local Util = {}

function Util.result<T>(value: T): Result<T>
    return { ok = true, value = value }
end

function Util.error<T>(error: ErrorCode): Result<T>
    return { ok = false, err = error }
end

return Util
