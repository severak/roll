#!/usr/bin/env lua
----
-- ROLL
----
-- Simple directory manager.
-- by Severák 2012
----

----
-- LIB
----
function parseIni(filename)
	local ret={}
	local section="default"
	for line in io.lines(filename) do
		if line:match("^;") then
			--komentáø
		elseif line:match("^.+=.+") then
			local k,v = line:match("([^=]+)=(.+)%s")
			ret[section] = ret[section] or {}
			ret[section][k] = v
		elseif line:match("%[.+%]") then
			section=line:match("%[(.+)%]")
		end
	end
	return ret
end

function splitComma(text)
	local list={}
	for word in text:gmatch("([^,]+),-") do
		if not (word=="") then
			list[#list+1] = word
		end
	end
	return list
end

function list(subjs, cfg)
	for _,name in pairs(subjs) do
		print(string.format("[%s] (driver:%s)", name, cfg[name]["type"] or "unknown"))
		if cfg[name]["info"] then
			print(cfg[name]["info"])
		end
		print("")
	end
end

function doCmd(subj, cmd, conf)
	if driver[conf.type] then
		if type(driver[conf.type][cmd])=="function" then
			local ok=driver[conf.type][cmd](conf)
			if not ok then
				print(string.format("[%s] command %s failed! (driver %s)", subj, cmd, conf.type))
			end
		end
	elseif conf.type then
		print(string.format("[%s] Invalid driver %s!", subj, conf.type))
	else
		print(string.format("[%s] Unknown driver!", subj))
	end
end

function query(query, cfg)
	local ret={}
	if query=="." then
		for k,_ in pairs(cfg) do
			ret[#ret+1]=k
		end
	elseif query:match("^@.+") then
		local category=query:match("^@(.+)")
		for k,v in pairs(cfg) do
			if v.tags and v.tags:match("%s-".. category .."%s-") then
				ret[#ret+1]=k
			end
		end
	else
		ret=splitComma(query)
	end
	table.sort(ret)
	return ret
end

function mkdirIfNot(path)
	if not (os.execute(string.format("cd %s 2> /dev/null", path))==0) then
			os.execute(string.format("mkdir -p %s", path))
	end
end

driver={}
----
-- DRIVERS
----

-- NOP DRIVER
driver.nop={}
driver.nop.up=function()
	return true
end
driver.nop.down=driver.nop.up

-- CURL HTTP DRIVER

driver["http-file"]={
	down = function(conf)
		if conf["local"]:match(".+/[^/]") then
			local dir=conf["local"]:match("(.+)/[^/]")
			mkdirIfNot(dir)
		end
		return os.execute(string.format("curl %s>%s",conf.remote, conf["local"]))==0
	end,
	up = function(conf)
		return false
	end,
	away = function(conf)
		return os.execute(string.format("rm %s", conf["local"]))==0
	end
}

-- FTP DRIVER (WGET/WPUT)

driver["ftp-dir"]={
	down = function(conf)
		return os.execute(string.format("wget --directory-prefix=%s --user=%s --password=%s %s/*",  conf["local"], conf.user, conf.pass, conf.remote))==0
	end,
	
	up = function(conf)
		local rem=conf.remote:match("ftp://(.+)")
		local rem=string.format("ftp://%s:%s@%s", conf.user, conf.pass, rem)
		return os.execute(string.format("wput %s %s", conf["local"], rem))==0
	end,
	
	away = function(conf)
		return os.execute(string.format("rm -rf %s", conf["local"]))
	end
	
	
}

-- FOSSIL DRIVER

driver["fossil"]={
	down=function(conf)
		--local ret=os.execute(string.format("cd %s;fossil status", conf["local"]))
		--print(ret)
		--os.exit()
		local ret=os.execute(string.format("fossil clone %s %s.foss", conf.remote, conf["local"]))
		if ret==0 then
			ret=os.execute(string.format("mkdir -p %s; cd %s; fossil open ../%s.foss", conf["local"], conf["local"], conf["local"]))
			if ret==0 then
				return true
			end
		end
	end
}

----
-- MAIN
----
local cfg=parseIni("roll.ini")
local cmd = arg[1] or "help"
if cmd=="list" then
	local subjs=query(arg[2] or ".", cfg)
	list(subjs, cfg)
else
	local subjs=query(arg[2] or ".", cfg)
	for _,subj in pairs(subjs) do
		doCmd(subj,cmd,cfg[subj])
	end
end

----
-- FINIS
----
