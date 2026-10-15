--!strict
-- Roblox Open Cloud for the wiki rankings (S125): the addresses, one request with retries and the readers of the
-- answers. No network here: `deps.send` does the HTTP call (tools/rankings_fetch.luau: @lune/net; tests: a mock), so
-- the retry rules are tested without waiting. The API key travels only in the x-api-key header and is never printed.

local OpenCloud = {}

-- Verify against https://create.roblox.com/docs/cloud (Open Cloud v2); the API may change.
OpenCloud.ENDPOINTS = table.freeze({
	-- TODO(owner): verify. Ordered data store entries, best first (the level and guild boards).
	ordered = "https://apis.roblox.com/cloud/v2/universes/{universe}/ordered-data-stores/{store}/scopes/global/entries?maxPageSize={n}&orderBy=value%20desc",
	-- TODO(owner): verify. One data store entry (metadata of an entry key, a Hall of Fame list).
	entry = "https://apis.roblox.com/cloud/v2/universes/{universe}/data-stores/{store}/scopes/global/entries/{entry}",
	-- TODO(owner): verify. Memory store sorted map items, best first (the weekly boards).
	sorted = "https://apis.roblox.com/cloud/v2/universes/{universe}/memory-store/sorted-maps/{map}/items?maxPageSize={n}&orderBy=desc",
})

OpenCloud.BACKOFF = table.freeze({ 1, 2, 4 }) -- s before a retry after 429 / 5xx / no answer
OpenCloud.PAUSE = 0.2 -- s after every request (stays under the API rate limits)

export type Response = { status: number, body: string }
export type Deps = {
	send: (url: string, key: string) -> Response, -- status 0 = no answer (network error)
	wait: (seconds: number) -> (),
	decode: (text: string) -> any, -- JSON
}

-- Percent-encodes one path or query value.
function OpenCloud.encode(text: string): string
	return (
		string.gsub(text, "[^%w%-%._~]", function(c: string): string
			return string.format("%%%02X", string.byte(c))
		end)
	)
end

-- The address of `kind` with its fields filled in (values encoded).
function OpenCloud.url(kind: string, fields: { [string]: string | number }): string
	local template = OpenCloud.ENDPOINTS[kind]
	if not template then
		error(`OpenCloud.url: unknown endpoint {kind}`)
	end
	return (
		string.gsub(template, "{(%w+)}", function(name: string): string
			local value = fields[name]
			if value == nil then
				error(`OpenCloud.url: {kind} needs {name}`)
			end
			return OpenCloud.encode(tostring(value))
		end)
	)
end

-- One GET with retries after 429, 5xx and no answer (1 / 2 / 4 s). Returns (ok, status, decoded body?).
function OpenCloud.request(url: string, key: string, deps: Deps): (boolean, number, any?)
	local status = 0
	for attempt = 1, #OpenCloud.BACKOFF + 1 do
		local response = deps.send(url, key)
		deps.wait(OpenCloud.PAUSE)
		status = response.status
		if status >= 200 and status < 300 then
			local ok, body = pcall(deps.decode, response.body)
			return ok, status, if ok then body else nil
		end
		local retry = status == 0 or status == 429 or status >= 500
		if not retry or attempt > #OpenCloud.BACKOFF then
			return false, status, nil
		end
		deps.wait(OpenCloud.BACKOFF[attempt])
	end
	return false, status, nil
end

-- Ordered data store entries of an answer: { { key, value } } best first.
function OpenCloud.orderedEntries(body: any): { { key: string, value: number } }
	local out = {}
	local list = if type(body) == "table" then body.orderedDataStoreEntries else nil
	for _, e in if type(list) == "table" then list else {} do
		local value = tonumber(e.value)
		if type(e.id) == "string" and value then
			table.insert(out, { key = e.id, value = value })
		end
	end
	return out
end

-- The value of a data store entry answer (nil when it has none).
function OpenCloud.entryValue(body: any): any?
	return if type(body) == "table" then body.value else nil
end

-- Sorted map items of an answer: { { key, value } } in answer order.
function OpenCloud.sortedItems(body: any): { { key: string, value: any } }
	local out = {}
	local list = if type(body) == "table" then body.memoryStoreSortedMapItems else nil
	for _, item in if type(list) == "table" then list else {} do
		if type(item.id) == "string" then
			table.insert(out, { key = item.id, value = item.value })
		end
	end
	return out
end

return OpenCloud
