/// Base class for generated jsoncls classes.
/// 
Class jsoncls.JSONable Extends (%RegisteredObject) {

Method %OnNew(initvalue As %String) As %Status
{
  if ( $data(initvalue) ) {
    set $this=..FromJSON(initvalue)
  }
  return $$$OK
}


ClassMethod ImportFromString(json As %String,Output sc As %Status) As jsoncls.JSONable
{
  try {
    set sc=$$$OK
    return ..FromJSON(json)
  } catch error {
    return error.AsStatus()
  }
}

ClassMethod ImportFromStream(stream As %Stream.Object,Output sc As %Status) As jsoncls.JSONable
{
  try {
    set sc=$$$OK
    return ..FromJSON(json)
  } catch error {
    return error.AsStatus()
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

ClassMethod FromJSON(json As %String) As jsoncls.JSONable   
{
    $$$THROWONERROR(sc,##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(json,..%ClassName(1),.obj,1))
    return obj
}

}
