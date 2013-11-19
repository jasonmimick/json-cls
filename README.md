json-cls

Generate Caché classes from json documents.
The purpose of this is to allow one to effiecently use JSON documents within the 
Ensemble pipeline. The generated classes can be used in request/response messages, business rules,
or data transformation.

From a terminal session you can generate a class like this:

<code>
ENSDEMO>read json
{ "name" : "Johnny Jones", "age" 45, "email" : { "work" : "jj@acme.com", "home" : "j23@email.com" } , "cars" : [ "Fiat", "Chevy", "Mazda", "Volvo" ] }

ENSDEMO>do ##class(jsoncls.Generator).Generate("foo.person",json)
</code>

This would then generate a class called foo.person.
