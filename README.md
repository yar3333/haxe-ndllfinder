Ndll haxe/neko library
======================

The problem of the standard `neko.Lib.load()` is a bad library path detection in some cases.
For example, if `ndll` loaded from neko.Web.cache() method (relative paths became unexpected).
Using `Ndll.load()` is the smart solution to prevent this problem.

```haxe
var func = NdllTools.load("myModule", "prim", argCount);
var func = NdllTools.loadLazy("myModule", "prim", argCount);
```
NdllTool.load() test next paths (example for Windows platform):

 * **FOLDER_OF_CURRENT_MODULE** / myModule-windows.ndll
 * **FOLDER_OF_CURRENT_MODULE** / ndll / Windows / myModule.ndll
 * **NEKOPATH** / myModule.ndll
 * **HAXELIBS** / myModule / **VERSION** / ndll / Windows / myModule.ndll