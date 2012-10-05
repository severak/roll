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
	local fh=io.open(filename,"r")
	if fh then
		fh:close()
	else
		print("Rollfile not found!")
		os.exit()
	end
	local ret={}
	local section="default"
	for line in io.lines(filename) do
		if line:match("^;") then
			--komentáø
		elseif line:match("^.+=.+") then
			local k,v = line:match("([^=]+)=(.+)")
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

function dirPart(path)
	local dp= string.match(path,"([^=]+)/.+") or "."
	return dp
end

function lastPart(path)
	local dp= string.match(path,"[^=]+/(.+)") or path
	return dp
end

function verbose(cmd)
	print(">"..cmd)
	return os.execute(cmd)
end

fileIn = function(conf, dest)
	mkdirIfNot(dirPart(dest.."/"..conf["local"]))
	return os.execute(string.format("cp %s %s", conf["local"], dest.."/"..conf["local"] ))==0
end

dirIn = function(conf, dest)
	mkdirIfNot(dest.."/"..conf["local"])
	return os.execute(string.format("cp -v -r %s/* %s", conf["local"], dest.."/"..conf["local"]))==0
end

function rollIn(subjs, cfg)
	local subjs=query(arg[2], cfg)
	local tmpdir=os.tmpname()
	os.execute(string.format("rm %s",tmpdir))
	os.execute(string.format("mkdir -p %s",tmpdir))
	for _,subj in pairs(subjs) do
		local conf=cfg[subj]
		local ret=nil
		if conf.type and driver[conf.type] and type(driver[conf.type]["in"])=="function" then
			ret=driver[conf.type]["in"](conf, tmpdir)
		end
		if ret then
			print(string.format("[%s] ok",subj))
		else
			print(string.format("[%s] failed",subj))
		end
	end
	local today=os.date("*t")
	local aname = string.format("bck%04d%02d%02d-%02d%02d.tgz", today.year, today.month, today.day, today.hour, today.min)
	os.execute(string.format("tar -czvf %s %s", aname,tmpdir))
	print(string.format("%s created!", aname))
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
driver.nop.away=driver.nop.up
driver.nop["in"] = function()
	print("nop driver not performing rolling in!")
	return false
end


-- CURL HTTP DRIVER

driver["http-file"]={
	down = function(conf)
		mkdirIfNot(dirPart(conf["local"]))
		return os.execute(string.format("wget -O %s %s", conf["local"], conf.remote))==0
	end,
	
	up = function(conf)
		return false
	end,
	
	away = function(conf)
		return os.execute(string.format("rm -v %s", conf["local"]))==0
	end,
	
	["in"] = fileIn
}

-- CP FILE

driver["cp-file"]={
	down = function(conf)
		mkdirIfNot(dirPart(conf["local"]))
		return os.execute(string.format("cp -v %s %s", conf.remote, conf["local"]))
	end,
	
	up = function(conf)
		mkdirIfNot(dirPart(conf.remote))
		return os.execute(string.format("cp -v %s %s", conf["local"], conf.remote))
	end,
	
	away = function(conf)
		return os.execute(string.format("rm -v %s", conf["local"]))
	end,
	
	["in"] = fileIn
}

-- CP DIR

driver["cp-dir"]={
	down = function(conf)
		mkdirIfNot(conf["local"])
		return os.execute(string.format("cp -v -r %s/* %s", conf.remote, conf["local"]))
	end,
	
	up = function(conf)
		mkdirIfNot(conf.remote)
		return os.execute(string.format("cp -v -r %s/* %s", conf["local"], conf.remote))
	end,
	
	away = function(conf)
		return os.execute(string.format("rm -r -v %s/*", conf["local"]))
	end,
	
	["in"] = dirIn
}

-- FTP DRIVER (WGET/WPUT)

driver["ftp-dir"]={
	down = function(conf)
		return os.execute(string.format("wget --directory-prefix=%s --user=%s --password=%s %s/*",  conf["local"], conf.user, conf.pass, conf.remote))==0
	end,
	
	up = function(conf)
		--local rem=conf.remote:match("ftp://(.+)")
		--local rem=string.format("ftp://%s:%s@%s", conf.user, conf.pass, rem)
		--return verbose(string.format("wput --basename=%s %s %s", dirPart(conf["local"]), conf["local"], rem))==0
		print("disabled due security reasons")
		return false
	end,
	
	away = function(conf)
		return os.execute(string.format("rm -v -r %s/*", conf["local"]))
	end,
	
	["in"] = dirIn
	
}

driver["ftp-file"]={
	down = function(conf)
		mkdirIfNot(dirPart(conf["local"]))
		return verbose(string.format("wget --user=%s --password=%s %s>%s", conf.user, conf.pass, conf.remote, conf["local"]))==0
	end,
	
	up = function(conf)
		local rem=conf.remote:match("ftp://(.+)")
		local rem=string.format("ftp://%s:%s@%s", conf.user, conf.pass, rem)
		return verbose(string.format("wput -u %s %s", conf["local"], rem))
	end,
	
	away = function(conf)
		return os.execute(string.format("rm -v %s", conf["local"]))==0
	end,
	
	["in"] = fileIn
	
}

-- FOSSIL DRIVER
-- this driver is very incomplete

--[[driver["fossil"]={
	down=function(conf)
		local ret=nil
		if os.execute(string.format("cd %s", conf["local"]))==0 then
			local ret=os.execute(string.format("cd %s;fossil status", conf["local"]))
		end
		if ret==0 then
			os.execute(string.format("cd %s;fossil pull", conf["local"]))
		else
			mkdirIfNot(".repos")
			local ret=os.execute(string.format("fossil clone %s .repos/%s.foss", conf.remote, lastPart(conf["local"])))
			if ret==0 then
				mkdirIfNot(conf["local"])
				local tmpf=os.tmpname()
				os.execute(string.format("pwd>%s",tmpf))
				local tmf=io.open(tmpf)
				local pwd=tmf:read()
				tmf:close()
				print(pwd)
				ret=os.execute(string.format("cd %s; fossil open %s/.repos/%s.foss", conf["local"], pwd, conf["local"]))
				if ret==0 then
					return true
				end
			end
		end
	end,
	
	up = function(conf)
		return nil
	end,
	
	away = function(conf)
	
	end
}]]

----
-- MAIN
----
local cfg=parseIni("roll.ini")
local cmd = arg[1] or "help"
if cmd=="list" then
	local subjs=query(arg[2] or ".", cfg)
	list(subjs, cfg)
elseif cmd=="in" then
	if arg[2] then
		local subjs=query(arg[2], cfg)
		rollIn(subjs, cfg)
	else
		print("What you want roll in?")
	end
	
else
	local subjs=query(arg[2] or ".", cfg)
	for _,subj in pairs(subjs) do
		doCmd(subj,cmd,cfg[subj])
	end
end

----
-- FINIS
----
