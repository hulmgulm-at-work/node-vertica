EventEmitter    = require('events').EventEmitter
OutgoingMessage = require('./outgoing_message')

class Query extends EventEmitter
  
  constructor: (@connection, sql) ->
    
    @connection._writeMessage(new OutgoingMessage.Query(sql))
    
    @connection.once 'RowDescription',  @onRowDescription.bind(this)
    @connection.on "DataRow",           @onDataRow.bind(this)
    @connection.once 'CommandComplete', @onCommandComplete.bind(this)
    @connection.once 'ErrorResponse',   @onErrorResponse.bind(this)
  
  onRowDescription: (msg) ->
    @fields = []
    for column in msg.columns
      field = new Query.Field(column)
      @emit 'field', field
      @fields.push field
      
    @emit 'fields', @fields
    
  onDataRow: (msg) ->
    row = []
    for value, index in msg.values
      row.push @fields[index].convert(value)
    
    @emit 'row', row
    
  onCommandComplete: (msg) ->
    @connection.removeAllListeners "DataRow"
    @connection.removeAllListeners "ErrorResponse"
    @emit 'end', msg.status
    
  onErrorResponse: (msg) ->
    @connection.removeAllListeners "RowDescription"
    @connection.removeAllListeners "DataRow"
    @connection.removeAllListeners "CommandComplete"
    
    @emit 'error', msg

converters =
  string:  (value) -> value.toString()
  integer: (value) -> parseInt(value)

fieldConverters =
  0: # text encoded
    1043: converters.string
    23: converters.integer 



class Query.Field
  constructor: (msg) ->
    @name       = msg.name
    @tableId    = msg.tableId
    @fieldIndex = msg.fieldIndex
    @type       = msg.type
    @size       = msg.size
    @modifier   = msg.modifier
    @formatCode = msg.formatCode
    
    @convert = fieldConverters[@formatCode][@type] || ((value) -> value.toString())

module.exports = Query
