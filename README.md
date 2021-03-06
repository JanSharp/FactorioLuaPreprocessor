
# Workspace setup

This project uses
- [Lua 5.4](http://www.lua.org/manual/5.4/)
- [LuaFileSystem](https://keplerproject.github.io/luafilesystem/index.html)

And for development
- [vscode](https://code.visualstudio.com/)
- [sumneko.lua](https://marketplace.visualstudio.com/items?itemName=sumneko.lua)
- [sumneko.lua plugin](https://github.com/JanSharp/FactorioSumnekoLuaPlugin)
- [tomblind.local-lua-debugger-vscode](https://marketplace.visualstudio.com/items?itemName=tomblind.local-lua-debugger-vscode)

## Notes for setup process

This mostly applies mostly for windows, but i believe it's actually easier on linux.

All the env variables that get added/modified i just did system wide because imo that makes sense, but it's up to you if you want system or user i suppose.

- download Lua 5.4 source
- decompress it (for example using `7Zip`)
- decide where you want to have your lua binaries located and create the folder for it
- copy all files from the `src` dir of the downloaded source into the previously mentioned folder (this is for luarocks installing LuaFileSystem later on)
- install `chocolatey`
- `choco install make`
- `choco install mingw`
- open some terminal relative to the originally extracted `src` folder, there should be a `Makefile` and a `README` file in there
- `make mingw`
- copy the now created `lua.exe`, `lua54.dll` and `luac.exe` files from the `src` folder to the folder you decided to have your binaries in (which also has all the source files from earlier)
- add that folder to the environment variable `PATH` (search for `env` or `path` in windows)
- download and extract or somehow install [luarocks](https://luarocks.org/)
- add the folder `luarocks.exe` is in to `PATH` too
- i believe for the next command you need to run whatever terminal you're using in administrator mode
- `luarocks config --system lua_dir <the FOLDER that you decided to put the lua binaries in> --lua-version 5.4`
- (i hope i remembered that command correctly, but i think i did)
- if that didn't work try looking at [this](https://github.com/luarocks/luarocks/wiki/Installation-instructions-for-Windows) and [that](https://github.com/luarocks/luarocks/wiki/config) and if you're not sure if it worked, try and see if the next step works
- `luarocks install luafilesystem`
- it should tell you that it was successful and where it installed. For me that was in my user dir under `~/.luarocks/lib/lua/5.4/lfs.dll`
- locate wherever your dll is
- if the env variable `LUA_CPATH` already exists, add that location to it like described below (skip the next step)
- `lua -e "print(package.cpath)"` (this is running your generated lua binaries thanks to it being in `PATH`)
- add the env variable `LUA_CPATH` with the value of what the previous command printed plus a `;` separator plus the location of your lfs dll, using mine as an example: `<what package.cpath used to be>;C:\Users\<usr>\.luarocks\lib\lua\5.4\?.dll`
- if you ever wondered what the default `package.cpath` was add the `-E` option to the command, so `lua -E -e "print(package.cpath)"`
- and finally done

if something is not working or you want to do things differently or you wonder how something works go ahead and search online, as usual, but here are some pointers
- Lua 5.4 manual, for example for cpath and `lua.exe` program args
- all the official pages of the software referenced here

And just a few more things
- adjust `settings.json` and or user settings as needed for the extensions in vscode
- the launch profile in `launch.json` should technically work but you probably want to copy it and use custom paths
- if the debugger failes to launch check the `lua-local.interpreter` (user) setting. It should probably just be `lua`, it's the name of the lua executable, which is in `PATH`, so `lua` alone should do
