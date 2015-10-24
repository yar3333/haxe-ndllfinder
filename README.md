Ndll haxe/neko library
======================

The problem of the standard `neko.Lib.load()` is a bad library path detection in some cases.
For example, if `ndll` loaded from neko.Web.cache() method then relative paths specified by NEKOPATH became unexpected.
Just compile your project with this library to use the smart searching of the ndll files.

CAUTION: this library override neko.Lib class so it may be incompatible with libraries which do the same thing.

Fixed `neko.Lib.load("myModule", ..., ...)` check next paths (example for Windows platform):

 1. **FOLDER_OF_CURRENT_MODULE** / myModule-windows.ndll
 2. **FOLDER_OF_CURRENT_MODULE** / ndll / Windows / myModule.ndll
 3. **NEKOPATH** / myModule.ndll
 
Library tested in the next situations:

 * `neko test.n'
 * `test.exe` - produced by `nekotools boot test.n`
 * `http://site/test.n` - mod_neko / without neko.Web.cache()
 * `http://site/test.n` - mod_neko / with neko.Web.cache()
 