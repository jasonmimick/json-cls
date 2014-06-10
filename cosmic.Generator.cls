Class cosmic.Generator Extends %RegisteredObject 
{
    
ClassMethod Generate(className As %String, jsonSource as %RegisteredObject) 
{
    try {
        do ..gen(className, jsonSource)
    } catch error {
        do error.OutputToDevice()
    }
}

ClassMethod exp(message as %String) [ Private ]
{
    return ##class(%Exception.General).%New("cosmic",,,message)
}

/// Internal implementation
///
ClassMethod gen(className As %String, jsonSource as %RegisteredObject) [ Private ] 
{
 set jStream = "" 
 // Normalize source to some %Stream.Object
 if ( '$isobject(jsonSource) ) {    // just a string
    set jStream = ##class(%Stream.TmpCharacter).%New()
    do jStream.Write( jsonSource ) 
    do jStream.Rewind()

 } 
 if ( $isobject(jsonSource) && 'jsonSource.%Extends("%Stream.Object") ) {   // hmm...
    throw ..exp("Unable to process jsonSource, must be a String or some %Stream object") 
 } else {
     set jStream=jsonSource
 }

 // Convert to %ZEN.proxyObject
 $$$THROWONERROR(sc,##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(jStream,,.jP))

 // Generate class   
 //zw jP
 //do jP.%CopyToArray(.jA)
 //zw jA
 do ..genCls(className,jP)

}

ClassMethod dbg() [ codemode = expression ] 
{
  $get(^||debug)
}
ClassMethod genCls(className As %String,proxyObject as %ZEN.proxyObject,nested=0) [ Private ]
{
    if ( ..dbg() ) {
      Write "genCls className=",className,!
      zw proxyObject
    }
    do proxyObject.%CopyToArray(.proxyArray)
	do {
		if ( '$data(^||ns) ) {
			set ^||ns=$namespace
		}
		new $namespace set $namespace=^||ns
		if ( $data(^oddDEF(className) ) ) {

        	do $system.OBJ.Delete( className,"-d" )
    	}
	} while (0) 
    set cdef=##class(%Dictionary.ClassDefinition).%New(className)
    set:'nested cdef.Super = "cosmic.JSONable,%Persistent"   //Ens.Request"
    set:nested cdef.Super = "%SerialObject"
    write:..dbg() "cdef.Super=",cdef.Super,!
    set cdef.ProcedureBlock = 1
	set cdef.ClassType="persistent"
    set prop=$order(proxyArray(""))
	while ( prop'="" ) {
        set v=proxyArray(prop)
        set cp = ##class(%Dictionary.PropertyDefinition).%New()
        set cp.Name = prop
        if ( '$isobject(v) ) {
            if ( v?.N ) {
                set cp.Type="%Integer"
            } else {
                set cp.Type="%String"
            }
            do cdef.Properties.Insert(cp)
            goto keepOnTruckin
        }
        if ( v.%Extends("%ZEN.proxyObject") ) { 
            // generae a class for this type
            // add a property to this class for that type
            do ..genCls(className_"."_prop, v, 1 )
            set cp.Type = className_"."_prop
            do cdef.Properties.Insert(cp)
            goto keepOnTruckin
        }
        if ( v.%Extends("%Library.ListOfDataTypes") ) {
            set cp.Type="%Library.DataType"
            set cp.Collection = "list"
            do cdef.Properties.Insert(cp)
            goto keepOnTruckin    
        }

        if ( v.%Extends("%Library.ListOfObjects") ) {
            // Here we expect a consitent object definition
            // Grab the first one in the list and generate the type
            set lt=v.GetAt(1)
            do ..genCls(className_"."_prop, lt, 1 )

            set cp.Type=className_"."_prop
            set cp.Collection = "list"
            do cdef.Properties.Insert(cp)
            goto keepOnTruckin    
 
        }
        // 1. Simple value - support String/Integer        
        // 2. Array of objects
        // 3. Array of simple types
        // 4. Nested Object?
keepOnTruckin
        set prop=$order(proxyArray(prop))
    }
    set compileFlags="ck-d"
	set:($get(^||debug)) compileFlags="ckd"
	if ( $data(^||ns ) ) {
      new $namespace set $namespace=^||ns
      do cdef.%Save()
      do $system.OBJ.Compile(cdef.Name,compileFlags)
    } else {
      do cdef.%Save()
      do $system.OBJ.Compile(cdef.Name,compileFlags)
    }
}

ClassMethod test1() 
{
    set ^foofee=0
    set j="{ ""name"" : ""John"", ""age"" : 55 }"
    write j,!
    do ..Generate("cosmic.test.one",j)   
    set sc=##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(j,"cosmic.test.one",.jone,1)
    zw jone

    set stream=##class(%Stream.TmpCharacter).%New()
    set sc=##class(%ZEN.Auxiliary.jsonProvider).%WriteJSONStreamFromObject(stream,jone)
    do stream.OutputToDevice()

    set j="{ ""nest"" : { ""one"" : 1, ""two"" : 2 } }"
    do ..Generate("cosmic.test.two",j)   

    set j2=##class(cosmic.test.two).FromJSON(j)
    zw j2
    write j2.ToJSON()
    
    set j="{ ""arrays"" : [ ""They"", ""really"", ""rock"", 100 ]}"
    do ..Generate("cosmic.test.three",j)
    set j3=##class(cosmic.test.three).FromJSON(j)
    zw j3
    write !,j3.ToJSON(),!

    set ^foofee=1
    set j="{ ""nestArray"" : [ { ""Color"" : ""Red"", ""Name"" : ""Cardinal"" }, { ""amount"" :""55"" }, { ""q"" : ""Will this work?""} ] }"
    set ^j=j
    do ..Generate("cosmic.test.four",j)
    set j4=##class(cosmic.test.four).FromJSON(j)
    zw j4
    set na=j4.nestArray
    zw na
    for i=1:1:na.Count() {
      set nai=na.GetAt(i)
      zw nai
    }

    write !,j4.ToJSON(),!

}
    
}
