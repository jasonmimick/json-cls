# cosmic

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
Now go off and build data transforms against your JSON generated classes!

Even better, cosmic supports a REST endpoint, which allows you to generate classes and 
post/get data from the system.

`curl -X POST --header "content-type:application/json" --header "x-cosmic-action:create" --header "x-cosmic-namespace:user" -d "{ \"message\" : \"Hello World!\" }" http://_user_:_pwd_@server:57772/cosmic/demo.message
`

Would generate a Caché class called 'demo.message' with one %String property called message.
Send that same post again, but remove the x-cosmic-action header and cosmic would store the JSON document.

Queries work in a similar fashion.

`
curl -X GET --header "x-cosmic-namespace:user" http://_user_:_pwd_@server:57772/cosmic/demo.message?message[Hello
`

Will return all the documents where the message property contains "Hello".

### Query Operators

| symbol |	meaning		|	example			|
|--------|--------------|------------------:|
|   =	 | Equal		| ?color=Yellow	    |
|	<	 | Less than	| ?age<21			|
|	>	 | Greater than | ?age>65			|
|	[	 | Contains 	| ?name[Smith		|
|   ~	 | Like		    | ?city~San	 		|
|   |	 | Or			| ?city~San|city~New|
|   +	 | AND 		    | ?city~San+state=CA|


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
