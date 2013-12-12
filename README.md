# json-cls

## Generate Caché classes from json documents

Now you can effeciently use JSON documents within the Ensemble pipeline. 
The generated classes can be used in request/response messages, business rules, or data transformation.

From a terminal session you can generate a class like this:

<pre>
ENSDEMO>read json
{ "name" : "Johnny Jones", "age" 45, "email" : { "work" : "jj@acme.com", "home" : "j23@email.com" } , "cars" : [ "Fiat", "Chevy", "Mazda", "Volvo" ] }

ENSDEMO>do ##class(jsoncls.Generator).Generate("foo.person",json)
</pre>

This would then generate a class called foo.person.
No go off and build data transforms against your JSON generated classes!

## Installation

Use https://github.com/jasonmimick/shed.git!
`shed -ns user git-pull jasonmimick/shed`
That would pull all the required classes into the user namespace of your shed configured Caché instance.
Or, clone and load manually.

## Limitations

* Arrays can't mix objects and regular types (string, numbers, etc).

If you want to store a collection of strongly typed objects, then the array must contain consistency in the objects.
That is, you can mix differnt objects in a list:

This will not work
`{ "objects" : [ { "a" : "b" }, { "c" : "d" } ] }`

but this will

`{ "objects" : [ { "a" : "b" }, { "a" : "d" } ] }`
