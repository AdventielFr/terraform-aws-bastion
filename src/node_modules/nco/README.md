# nco

A function that acts as a Null-Coalescing Operator (nco) for npm and node. This is a terse way of setting default values.

You can read more about null-coalescing operators here:
https://en.wikipedia.org/wiki/Null_coalescing_operator

Usage:
```js
const nco = require('nco');
function myFunction(var1, var2) {
  var1 = nco(var1, 'default1');
  //if var1 was null or undefined, it will now be 'default1'
  var2 = nco(var2, 'default2');
  //etc.
}
```

The example usage written in C#, which uses `??` as a null-coalescing operator:
```c#
void MyFunction(string var1, string var2) {
  var1 = var1 ?? "default1";
  var2 = var2 ?? "default2";
  //etc.
}
```
