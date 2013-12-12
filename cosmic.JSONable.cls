/// Base class for generated cosmic classes.
/// 
Class cosmic.JSONable Extends (%RegisteredObject) {

Method %OnNew(initvalue As %String) As %Status
{
  if ( $data(initvalue) ) {
    set $this=..FromJSON(initvalue)
  }
  return $$$OK
}


ClassMethod ImportFromString(json As %String,Output sc As %Status) As cosmic.JSONable
{
  try {
    set sc=$$$OK
    return ..FromJSON(json)
  } catch error {
    return error.AsStatus()
  }
}

ClassMethod ImportFromStream(stream As %Stream.Object,Output sc As %Status) As cosmic.JSONable
{
  try {
    set sc=$$$OK
    set json=""
    do stream.Rewind()
    while ( 'stream.AtEnd ) { set json=json_stream.Read() }
    return ..FromJSON(json)
  } catch error {
    set sc=error.AsStatus()
    return 0
  }
}

Method ToJSON() As %String
{
    set stream=##class(%Stream.TmpCharacter).%New()
    set sc=##class(%ZEN.Auxiliary.jsonProvider).%WriteJSONStreamFromObject(stream,$this)
    set json=""
    while ( 'stream.AtEnd ) { set json=json_stream.Read() }
    return json

}

ClassMethod FromJSON(json As %String) As cosmic.JSONable   
{
    $$$THROWONERROR(sc,##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(json,..%ClassName(1),.obj,1))
    return obj
}

}
