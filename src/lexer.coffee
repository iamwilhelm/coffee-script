sys: require 'sys'

# The lexer reads a stream of CoffeeScript and divvys it up into tagged
# tokens. A minor bit of the ambiguity in the grammar has been avoided by
# pushing some extra smarts into the Lexer.
exports.Lexer: lex: ->

# The list of keywords passed verbatim to the parser.
lex.KEYWORDS: [
  "if", "else", "then", "unless",
  "true", "false", "yes", "no", "on", "off",
  "and", "or", "is", "isnt", "not",
  "new", "return", "arguments",
  "try", "catch", "finally", "throw",
  "break", "continue",
  "for", "in", "of", "by", "where", "while",
  "delete", "instanceof", "typeof",
  "switch", "when",
  "super", "extends"
]

# Token matching regexes.
lex.IDENTIFIER : /^([a-zA-Z$_](\w|\$)*)/
lex.NUMBER     : /^(\b((0(x|X)[0-9a-fA-F]+)|([0-9]+(\.[0-9]+)?(e[+\-]?[0-9]+)?)))\b/i
lex.STRING     : /^(""|''|"([\s\S]*?)([^\\]|\\\\)"|'([\s\S]*?)([^\\]|\\\\)')/
lex.HEREDOC    : /^("{6}|'{6}|"{3}\n?([\s\S]*?)\n?([ \t]*)"{3}|'{3}\n?([\s\S]*?)\n?([ \t]*)'{3})/
lex.JS         : /^(``|`([\s\S]*?)([^\\]|\\\\)`)/
lex.OPERATOR   : /^([+\*&|\/\-%=<>:!?]+)/
lex.WHITESPACE : /^([ \t]+)/
lex.COMMENT    : /^(((\n?[ \t]*)?#.*$)+)/
lex.CODE       : /^((-|=)>)/
lex.REGEX      : /^(\/(.*?)([^\\]|\\\\)\/[imgy]{0,4})/
lex.MULTI_DENT : /^((\n([ \t]*))+)(\.)?/
lex.LAST_DENT  : /\n([ \t]*)/
lex.ASSIGNMENT : /^(:|=)$/

# Token cleaning regexes.
lex.JS_CLEANER      : /(^`|`$)/
lex.MULTILINER      : /\n/
lex.STRING_NEWLINES : /\n[ \t]*/
lex.COMMENT_CLEANER : /(^[ \t]*#|\n[ \t]*$)/
lex.NO_NEWLINE      : /^([+\*&|\/\-%=<>:!.\\][<>=&|]*|and|or|is|isnt|not|delete|typeof|instanceof)$/
lex.HEREDOC_INDENT  : /^[ \t]+/

# Tokens which a regular expression will never immediately follow, but which
# a division operator might.
# See: http://www.mozilla.org/js/language/js20-2002-04/rationale/syntax.html#regular-expressions
lex.NOT_REGEX: [
  'IDENTIFIER', 'NUMBER', 'REGEX', 'STRING',
  ')', '++', '--', ']', '}',
  'FALSE', 'NULL', 'TRUE'
]

# Tokens which could legitimately be invoked or indexed.
lex.CALLABLE: ['IDENTIFIER', 'SUPER', ')', ']', '}', 'STRING']

# Scan by attempting to match tokens one character at a time. Slow and steady.
lex::tokenize: (code) ->
  this.code    : code.chomp # Cleanup code by remove extra line breaks
  this.i       : 0          # Current character position we're parsing
  this.line    : 1          # The current line.
  this.indent  : 0          # The current indent level.
  this.indents : []         # The stack of all indent levels we are currently within.
  this.tokens  : []         # Collection of all parsed tokens in the form [:TOKEN_TYPE, value]
  this.spaced  : nil        # The last value that has a space following it.
  while this.i < this.code.length
    this.chunk: this.code[this.i..-1]
    this.extract_next_token()
  sys.puts "original stream: #{@tokens.inspect}" if process.ENV['VERBOSE']
  this.close_indentation()
  (new Rewriter()).rewrite(this.tokens)

# At every position, run through this list of attempted matches,
# short-circuiting if any of them succeed.
lex::extract_next_token: ->
  return if this.identifier_token()
  return if this.number_token()
  return if this.heredoc_token()
  return if this.string_token()
  return if this.js_token()
  return if this.regex_token()
  return if this.indent_token()
  return if this.comment_token()
  return if this.whitespace_token()
  return    this.literal_token()

# Look at a tag in the current token stream.
lex::tag: (index, tag) ->
  return unless tok: this.tokens[index || -1]
  return tok[0]: tag if tag?
  tok[0]

# Look at a value in the current token stream.
lex::value: (index, val) ->
  return unless tok: this.tokens[index || -1]
  return tok[1]: val if val?
  tok[1]

# Tokenizers ==========================================================

# Matches identifying literals: variables, keywords, method names, etc.
lex::identifier_token: ->
  match: this.chunk.match(lex.IDENTIFIER)
  return false unless match and id: match[1]
  # Keywords are special identifiers tagged with their own name,
  # 'if' will result in an ['IF', "if"] token.
  tag: if this.KEYWORDS.indexOf(id) >= 0 then id.toUpperCase() else 'IDENTIFIER'
  tag: 'LEADING_WHEN' if tag is 'WHEN' and (this.tag() is 'OUTDENT' or this.tag() is 'INDENT')
  this.tag(-1, 'PROTOTYPE_ACCESS') if tag is 'IDENTIFIER' and this.value() is '::'
  if tag is 'IDENTIFIER' and this.value() is '.' and !(this.value(-2) is '.')
    if this.tag(-2) is '?'
      this.tag(-1, 'SOAK_ACCESS')
      this.tokens.splice(-2, 1)
    else
      this.tag(-1, 'PROPERTY_ACCESS')
  this.token(tag, id)
  this.i += id.length

























