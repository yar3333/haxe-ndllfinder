/*
 * Copyright (C)2005-2012 Haxe Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
package neko;

import haxe.io.Path;
import neko.vm.Loader;
import neko.vm.Module;
import sys.FileSystem;
using StringTools;

class Lib {

	/**
		Load and return a Neko primitive from a NDLL library.
	**/
	static function loadInner( lib : String, prim : String, nargs : Int ) : Dynamic {
		return untyped __dollar__loader.loadprim((lib+"@"+prim).__s,nargs);
	}

	public static function loadLazy(lib,prim,nargs) : Dynamic {
		try {
			return load(lib,prim,nargs);
		} catch( e : Dynamic ) {
			return untyped __dollar__varargs(function(_) { throw e; });
		}
	}

	/**
		Print the specified value on the default output.
	**/
	public static function print( v : Dynamic ) : Void {
		untyped __dollar__print(v);
	}

	/**
		Print the specified value on the default output followed by a newline character.
	**/
	public static function println( v : Dynamic ) : Void {
		untyped __dollar__print(v,"\n");
	}

	/**
		Rethrow an exception. This is useful when manually filtering an exception in order
		to keep the previous exception stack.
	**/
	public static function rethrow( e : Dynamic ) : Dynamic {
		return untyped __dollar__rethrow(e);
	}

	/**
		Serialize using native Neko serialization. This will return a Binary string that can be
		stored for long term usage. The serialized data is optimized for speed and not for size.
	**/
	public static function serialize( v : Dynamic ) : haxe.io.Bytes {
		return haxe.io.Bytes.ofData(__serialize(v));
	}

	/**
		Unserialize a string using native Neko serialization. See [serialize].
	**/
	public static function unserialize( s : haxe.io.Bytes ) : Dynamic {
		return untyped __unserialize(s.getData(),__dollar__loader);
	}

	/**
		Unserialize a string using native Neko serialization. See [serialize].
		This function assume that all the serialized data was serialized with current
		module, even if the module name was different. This can happen if you are unserializing
		some data into mod_neko that was serialized on a different server using a different
		file path.
	**/
	public static function localUnserialize( s : haxe.io.Bytes ) : Dynamic {
		return untyped __unserialize(s.getData(),{
			loadmodule : function(m,l) { return __dollar__exports; },
			loadprim : function(p,n) { return __dollar__loader.loadprim(p,n); }
		});
	}

	/**
		Converts a Neko value to its Haxe equivalent. Used for wrapping String and Arrays raw values into Haxe Objects.
	**/
	public static function nekoToHaxe( v : Dynamic ) : Dynamic untyped {
		switch( __dollar__typeof(v) ) {
		case 0: return v;
		case 1: return v;
		case 2: return v;
		case 3: return v;
		case 4: return new String(v);
		case 6:
			var a = Array.new1(v,__dollar__asize(v));
			for( i in 0...a.length )
				a[i] = nekoToHaxe(a[i]);
			return a;
		case 5:
			var f = __dollar__objfields(v);
			var i = 0;
			var l = __dollar__asize(f);
			var o = __dollar__new(v);
			if( __dollar__objgetproto(v) != null )
				throw "Can't convert object prototype";
			while( i < l ) {
				__dollar__objset(o,f[i],nekoToHaxe(__dollar__objget(v,f[i])));
				i += 1;
			}
			return o;
		default:
			throw "Can't convert "+string(v);
		}
	}

	/**
		Converts a Haxe value to its Neko equivalent. Used to unwrap String and Arrays Objects into raw Neko values.
	**/
	public static function haxeToNeko( v : Dynamic ) : Dynamic untyped {
		switch( __dollar__typeof(v) ) {
		case 0: return v;
		case 1: return v;
		case 2: return v;
		case 3: return v;
		case 5:
			var cl = v.__class__;
			if( cl == String )
				return v.__s;
			if( cl == Array ) {
				var a = untyped __dollar__amake(v.length);
				for( i in 0...v.length )
					a[i] = haxeToNeko(v[i]);
				return a;
			}
			if( cl != null || __dollar__objgetproto(v) != null )
				throw "Can't convert "+string(v);
			var f = __dollar__objfields(v);
			var i = 0;
			var l = __dollar__asize(f);
			var o = __dollar__new(v);
			while( i < l ) {
				__dollar__objset(o,f[i],haxeToNeko(__dollar__objget(v,f[i])));
				i += 1;
			}
			return o;
		default:
			throw "Can't convert "+string(v);
		}
	}

	/**
		Returns an object containing all compiled packages and classes.
	**/
	public static function getClasses() : Dynamic {
		return untyped neko.Boot.__classes;
	}

	/**
		Returns a string referencing the data contains in bytes.
	**/
	public inline static function stringReference( b : haxe.io.Bytes ) {
		return new String( cast b.getData() );
	}

	/**
		Returns bytes referencing the content of a string.
	**/
	public inline static function bytesReference( s : String ) : haxe.io.Bytes {
		return untyped new haxe.io.Bytes( s.length, s.__s );
	}
	
	static var __serialize = loadInner("std","serialize",1);
	static var __unserialize = loadInner("std","unserialize",2);
	
	
	static var baseDir : String;
	static var systemName : String;
	static var paths : Map<String, String>;
	
	/**
	 * Search for ndll file by library name. Returns path without ".ndll" extension.
	 * Paths to test: 
	 * 		1) <dir_of_*.n_file>/<name>-<platform>.ndll // for example: "c:/dir/curl-windows64.ndll";
	 * 		2) <dir_of_*.n_file>/ndll/<Platform>/<name>.ndll // for example: "c:/dir/ndll/Windows64/curl.ndll";
	 * 		3) <std_paths_(NEKOPATH)>/<name>.ndll;
	 * 		4) <path_from_haxelib>/ndll/<Platform>/<name>.ndll // C:/motion-twin/haxe/lib/hant/1,5,2/ndll/Windows64/hant.ndll.
	 */
	public static function getPath(lib:String, throwNotFound=false) : String
	{
		if (lib == "std" || StringTools.startsWith(lib, "mod_neko")) return lib;
		
		if (paths == null) paths = new Map<String, String>();
		
		if (paths.exists(lib)) return paths.get(lib);
		
		if (baseDir == null)
		{
			var moduleName = Module.local().name;
			baseDir = Path.directory(moduleName != "" ? moduleName : Sys.executablePath());
			if (baseDir == "") baseDir = ".";
			baseDir = FileSystem.fullPath(baseDir);
		}
		
		var testedPaths = [];
		
		if (systemName == null)
		{
			systemName = "" + Sys.systemName() + (loadInner("std", "sys_is64", 0)() ? "64" : "");
		}
		
		{
			var s = baseDir + "/" + lib + "-" + systemName.toLowerCase();
			if (FileSystem.exists(s + ".ndll"))
			{
				paths.set(lib, s);
				return s;
			}
			testedPaths.push(s);
		}
		
		{
			var s = baseDir + "/ndll/" + systemName + "/" + lib;
			if (FileSystem.exists(s + ".ndll"))
			{
				paths.set(lib, s);
				return s;
			}
			testedPaths.push(s);
		}
		
		for (path in Loader.local().getPath())
		{
			var s = Path.addTrailingSlash(path) + lib;
			if (FileSystem.exists(s + ".ndll"))
			{
				paths.set(lib, s);
				return s;
			}
			testedPaths.push(s);
		}
		
		if (throwNotFound) throw "Ndll flle for library '" + lib + "' is not found. Tested paths = " + testedPaths + ".";
		
		return lib;
	}
	
	public static inline function load(lib:String, prim:String, nargs:Int) : Dynamic
	{
		#if !macro
		return loadInner(getPath(lib, true), prim, nargs);
		#else
		return loadInner(lib, prim, nargs);
		#end
	}
}
