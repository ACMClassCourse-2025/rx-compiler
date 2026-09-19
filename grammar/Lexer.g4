// Rx course lexer. ANTLR 4.13.2; no target-specific actions or predicates.
lexer grammar Lexer;

AS: 'as';
BREAK: 'break';
CONST: 'const';
CONTINUE: 'continue';
CRATE: 'crate';
ELSE: 'else';
FALSE: 'false';
FN: 'fn';
IF: 'if';
IMPL: 'impl';
LET: 'let';
LOOP: 'loop';
MUT: 'mut';
RETURN: 'return';
SELF_VALUE: 'self';
SELF_TYPE: 'Self';
STATIC: 'static';
STRUCT: 'struct';
SUPER: 'super';
TRUE: 'true';
USE: 'use';
WHERE: 'where';
WHILE: 'while';

RESERVED_KEYWORD
    : 'enum' | 'extern' | 'for' | 'in' | 'match' | 'mod' | 'move'
    | 'pub' | 'ref' | 'trait' | 'type' | 'unsafe' | 'async' | 'await' | 'dyn'
    | 'abstract' | 'become' | 'box' | 'do' | 'final' | 'macro' | 'override'
    | 'priv' | 'typeof' | 'unsized' | 'virtual' | 'yield' | 'try'
    ;

DERIVE: 'derive';
COPY: 'Copy';
CLONE: 'Clone';
PARTIAL_EQ: 'PartialEq';
EQ: 'Eq';
UNDERSCORE: '_';

IDENTIFIER
    : ASCII_START ASCII_CONTINUE*
    ;

// Invalid tokens deliberately remain on the default channel. A parser must
// never silently recover and then compile a tree after reporting any error.
INVALID_LIFETIME
    : '\'' (AS | BREAK | CONST | CONTINUE | CRATE | ELSE | FALSE | FN | IF
      | IMPL | LET | LOOP | MUT | RETURN | SELF_VALUE | SELF_TYPE | STRUCT
      | SUPER | TRUE | USE | WHERE | WHILE | RESERVED_KEYWORD)
    ;

INVALID_CHARACTER_LITERAL
    : '\'' ASCII_START ASCII_CONTINUE* '\''
    ;

LIFETIME
    : '\'' ASCII_START ASCII_CONTINUE*
    ;

INTEGER_LITERAL
    : (DECIMAL | BINARY | OCTAL | HEXADECIMAL) INTEGER_SUFFIX?
    ;

// Longer malformed numeric names must not split into an integer + identifier.
INVALID_NUMBER
    : [0-9] ASCII_CONTINUE*
    ;

// A > begins a maximal token: >, >=, >>, or >>=. The following modes
// emit its remaining characters with distinct types; genericClose consumes
// individual > pieces, whereas infix rules consume one complete remainder.
GT: '>' -> mode(AFTER_GT);
LT: '<';
LE: '<=';
EQEQ: '==';
NE: '!=';
ANDAND: '&&';
OROR: '||';
NOT: '!';
PLUS: '+';
MINUS: '-';
STAR: '*';
SLASH: '/';
PERCENT: '%';
CARET: '^';
AMP: '&';
PIPE: '|';
SHL: '<<';
ASSIGN: '=';
PLUS_ASSIGN: '+=';
MINUS_ASSIGN: '-=';
STAR_ASSIGN: '*=';
SLASH_ASSIGN: '/=';
PERCENT_ASSIGN: '%=';
CARET_ASSIGN: '^=';
AMP_ASSIGN: '&=';
PIPE_ASSIGN: '|=';
SHL_ASSIGN: '<<=';
DOT: '.';
COMMA: ',';
SEMI: ';';
COLON: ':';
PATHSEP: '::';
ARROW: '->';
HASH: '#';
LBRACE: '{';
RBRACE: '}';
LBRACKET: '[';
RBRACKET: ']';
LPAREN: '(';
RPAREN: ')';

WHITESPACE: SPACE_TEXT -> channel(HIDDEN);
LINE_COMMENT: LINE_COMMENT_TEXT -> channel(HIDDEN);
BLOCK_COMMENT: BLOCK_COMMENT_TEXT -> channel(HIDDEN);
UNTERMINATED_BLOCK_COMMENT: UNTERMINATED_COMMENT_TEXT;
ERROR_CHAR: .;

fragment ASCII_START: [a-zA-Z_];
fragment ASCII_CONTINUE: [a-zA-Z0-9_];
fragment DECIMAL: [0-9] [0-9_]*;
fragment BINARY: '0b' [01_]* [01] [01_]*;
fragment OCTAL: '0o' [0-7_]* [0-7] [0-7_]*;
fragment HEXADECIMAL: '0x' [0-9a-fA-F_]* [0-9a-fA-F] [0-9a-fA-F_]*;
fragment INTEGER_SUFFIX: 'i32' | 'u32' | 'isize' | 'usize';
fragment SPACE_TEXT: (' ' | '\t' | '\n' | '\r\n')+;
fragment LINE_COMMENT_TEXT: '//' [\u0000-\u0009\u000B-\u007F]*;

// Factoring runs of / and * ensures delimiters always win. In particular,
// an unterminated nested opener cannot fall back to ordinary comment text.
fragment COMMENT_PLAIN: [\u0000-\u0029\u002B-\u002E\u0030-\u007F];
fragment COMMENT_PART
    : COMMENT_PLAIN
    | '/'+ COMMENT_PLAIN
    | '*'+ COMMENT_PLAIN
    | '/'* BLOCK_COMMENT_TEXT
    ;
fragment BLOCK_COMMENT_TEXT
    : '/*' COMMENT_PART* '*'+ '/'
    ;
fragment UNTERMINATED_COMMENT_TEXT
    : '/*' COMMENT_PART* (('/'+ | '*'+)? EOF | '/'* UNTERMINATED_COMMENT_TEXT)
    ;


// Every non-continuation token ends this punctuation token. The aliases
// reuse the default rules, keeping all targets free of handwritten code.
mode AFTER_GT;

GT_SECOND: '>' -> mode(AFTER_SECOND_GT);
GE_EQ: '=' -> mode(DEFAULT_MODE);
AG_AS: AS -> type(AS), mode(DEFAULT_MODE);
AG_BREAK: BREAK -> type(BREAK), mode(DEFAULT_MODE);
AG_CONST: CONST -> type(CONST), mode(DEFAULT_MODE);
AG_CONTINUE: CONTINUE -> type(CONTINUE), mode(DEFAULT_MODE);
AG_CRATE: CRATE -> type(CRATE), mode(DEFAULT_MODE);
AG_ELSE: ELSE -> type(ELSE), mode(DEFAULT_MODE);
AG_FALSE: FALSE -> type(FALSE), mode(DEFAULT_MODE);
AG_FN: FN -> type(FN), mode(DEFAULT_MODE);
AG_IF: IF -> type(IF), mode(DEFAULT_MODE);
AG_IMPL: IMPL -> type(IMPL), mode(DEFAULT_MODE);
AG_LET: LET -> type(LET), mode(DEFAULT_MODE);
AG_LOOP: LOOP -> type(LOOP), mode(DEFAULT_MODE);
AG_MUT: MUT -> type(MUT), mode(DEFAULT_MODE);
AG_RETURN: RETURN -> type(RETURN), mode(DEFAULT_MODE);
AG_SELF_VALUE: SELF_VALUE -> type(SELF_VALUE), mode(DEFAULT_MODE);
AG_SELF_TYPE: SELF_TYPE -> type(SELF_TYPE), mode(DEFAULT_MODE);
AG_STATIC: STATIC -> type(STATIC), mode(DEFAULT_MODE);
AG_STRUCT: STRUCT -> type(STRUCT), mode(DEFAULT_MODE);
AG_SUPER: SUPER -> type(SUPER), mode(DEFAULT_MODE);
AG_TRUE: TRUE -> type(TRUE), mode(DEFAULT_MODE);
AG_USE: USE -> type(USE), mode(DEFAULT_MODE);
AG_WHERE: WHERE -> type(WHERE), mode(DEFAULT_MODE);
AG_WHILE: WHILE -> type(WHILE), mode(DEFAULT_MODE);
AG_RESERVED_KEYWORD: RESERVED_KEYWORD -> type(RESERVED_KEYWORD), mode(DEFAULT_MODE);
AG_DERIVE: DERIVE -> type(DERIVE), mode(DEFAULT_MODE);
AG_COPY: COPY -> type(COPY), mode(DEFAULT_MODE);
AG_CLONE: CLONE -> type(CLONE), mode(DEFAULT_MODE);
AG_PARTIAL_EQ: PARTIAL_EQ -> type(PARTIAL_EQ), mode(DEFAULT_MODE);
AG_EQ: EQ -> type(EQ), mode(DEFAULT_MODE);
AG_UNDERSCORE: UNDERSCORE -> type(UNDERSCORE), mode(DEFAULT_MODE);
AG_IDENTIFIER: IDENTIFIER -> type(IDENTIFIER), mode(DEFAULT_MODE);
AG_INVALID_LIFETIME: INVALID_LIFETIME -> type(INVALID_LIFETIME), mode(DEFAULT_MODE);
AG_INVALID_CHARACTER_LITERAL: INVALID_CHARACTER_LITERAL -> type(INVALID_CHARACTER_LITERAL), mode(DEFAULT_MODE);
AG_LIFETIME: LIFETIME -> type(LIFETIME), mode(DEFAULT_MODE);
AG_INTEGER_LITERAL: INTEGER_LITERAL -> type(INTEGER_LITERAL), mode(DEFAULT_MODE);
AG_INVALID_NUMBER: INVALID_NUMBER -> type(INVALID_NUMBER), mode(DEFAULT_MODE);
AG_LT: LT -> type(LT), mode(DEFAULT_MODE);
AG_LE: LE -> type(LE), mode(DEFAULT_MODE);
AG_NE: NE -> type(NE), mode(DEFAULT_MODE);
AG_ANDAND: ANDAND -> type(ANDAND), mode(DEFAULT_MODE);
AG_OROR: OROR -> type(OROR), mode(DEFAULT_MODE);
AG_NOT: NOT -> type(NOT), mode(DEFAULT_MODE);
AG_PLUS: PLUS -> type(PLUS), mode(DEFAULT_MODE);
AG_MINUS: MINUS -> type(MINUS), mode(DEFAULT_MODE);
AG_STAR: STAR -> type(STAR), mode(DEFAULT_MODE);
AG_SLASH: SLASH -> type(SLASH), mode(DEFAULT_MODE);
AG_PERCENT: PERCENT -> type(PERCENT), mode(DEFAULT_MODE);
AG_CARET: CARET -> type(CARET), mode(DEFAULT_MODE);
AG_AMP: AMP -> type(AMP), mode(DEFAULT_MODE);
AG_PIPE: PIPE -> type(PIPE), mode(DEFAULT_MODE);
AG_SHL: SHL -> type(SHL), mode(DEFAULT_MODE);
AG_PLUS_ASSIGN: PLUS_ASSIGN -> type(PLUS_ASSIGN), mode(DEFAULT_MODE);
AG_MINUS_ASSIGN: MINUS_ASSIGN -> type(MINUS_ASSIGN), mode(DEFAULT_MODE);
AG_STAR_ASSIGN: STAR_ASSIGN -> type(STAR_ASSIGN), mode(DEFAULT_MODE);
AG_SLASH_ASSIGN: SLASH_ASSIGN -> type(SLASH_ASSIGN), mode(DEFAULT_MODE);
AG_PERCENT_ASSIGN: PERCENT_ASSIGN -> type(PERCENT_ASSIGN), mode(DEFAULT_MODE);
AG_CARET_ASSIGN: CARET_ASSIGN -> type(CARET_ASSIGN), mode(DEFAULT_MODE);
AG_AMP_ASSIGN: AMP_ASSIGN -> type(AMP_ASSIGN), mode(DEFAULT_MODE);
AG_PIPE_ASSIGN: PIPE_ASSIGN -> type(PIPE_ASSIGN), mode(DEFAULT_MODE);
AG_SHL_ASSIGN: SHL_ASSIGN -> type(SHL_ASSIGN), mode(DEFAULT_MODE);
AG_DOT: DOT -> type(DOT), mode(DEFAULT_MODE);
AG_COMMA: COMMA -> type(COMMA), mode(DEFAULT_MODE);
AG_SEMI: SEMI -> type(SEMI), mode(DEFAULT_MODE);
AG_COLON: COLON -> type(COLON), mode(DEFAULT_MODE);
AG_PATHSEP: PATHSEP -> type(PATHSEP), mode(DEFAULT_MODE);
AG_ARROW: ARROW -> type(ARROW), mode(DEFAULT_MODE);
AG_HASH: HASH -> type(HASH), mode(DEFAULT_MODE);
AG_LBRACE: LBRACE -> type(LBRACE), mode(DEFAULT_MODE);
AG_RBRACE: RBRACE -> type(RBRACE), mode(DEFAULT_MODE);
AG_LBRACKET: LBRACKET -> type(LBRACKET), mode(DEFAULT_MODE);
AG_RBRACKET: RBRACKET -> type(RBRACKET), mode(DEFAULT_MODE);
AG_LPAREN: LPAREN -> type(LPAREN), mode(DEFAULT_MODE);
AG_RPAREN: RPAREN -> type(RPAREN), mode(DEFAULT_MODE);
AG_WHITESPACE: WHITESPACE -> type(WHITESPACE), channel(HIDDEN), mode(DEFAULT_MODE);
AG_LINE_COMMENT: LINE_COMMENT -> type(LINE_COMMENT), channel(HIDDEN), mode(DEFAULT_MODE);
AG_BLOCK_COMMENT: BLOCK_COMMENT -> type(BLOCK_COMMENT), channel(HIDDEN), mode(DEFAULT_MODE);
AG_UNTERMINATED_BLOCK_COMMENT: UNTERMINATED_BLOCK_COMMENT -> type(UNTERMINATED_BLOCK_COMMENT), mode(DEFAULT_MODE);
AG_ERROR_CHAR: ERROR_CHAR -> type(ERROR_CHAR), mode(DEFAULT_MODE);

// Every non-continuation token ends this punctuation token. The aliases
// reuse the default rules, keeping all targets free of handwritten code.
mode AFTER_SECOND_GT;

ASG_GT: '>' -> type(GT), mode(AFTER_GT);
SHR_EQ: '=' -> mode(DEFAULT_MODE);
ASG_AS: AS -> type(AS), mode(DEFAULT_MODE);
ASG_BREAK: BREAK -> type(BREAK), mode(DEFAULT_MODE);
ASG_CONST: CONST -> type(CONST), mode(DEFAULT_MODE);
ASG_CONTINUE: CONTINUE -> type(CONTINUE), mode(DEFAULT_MODE);
ASG_CRATE: CRATE -> type(CRATE), mode(DEFAULT_MODE);
ASG_ELSE: ELSE -> type(ELSE), mode(DEFAULT_MODE);
ASG_FALSE: FALSE -> type(FALSE), mode(DEFAULT_MODE);
ASG_FN: FN -> type(FN), mode(DEFAULT_MODE);
ASG_IF: IF -> type(IF), mode(DEFAULT_MODE);
ASG_IMPL: IMPL -> type(IMPL), mode(DEFAULT_MODE);
ASG_LET: LET -> type(LET), mode(DEFAULT_MODE);
ASG_LOOP: LOOP -> type(LOOP), mode(DEFAULT_MODE);
ASG_MUT: MUT -> type(MUT), mode(DEFAULT_MODE);
ASG_RETURN: RETURN -> type(RETURN), mode(DEFAULT_MODE);
ASG_SELF_VALUE: SELF_VALUE -> type(SELF_VALUE), mode(DEFAULT_MODE);
ASG_SELF_TYPE: SELF_TYPE -> type(SELF_TYPE), mode(DEFAULT_MODE);
ASG_STATIC: STATIC -> type(STATIC), mode(DEFAULT_MODE);
ASG_STRUCT: STRUCT -> type(STRUCT), mode(DEFAULT_MODE);
ASG_SUPER: SUPER -> type(SUPER), mode(DEFAULT_MODE);
ASG_TRUE: TRUE -> type(TRUE), mode(DEFAULT_MODE);
ASG_USE: USE -> type(USE), mode(DEFAULT_MODE);
ASG_WHERE: WHERE -> type(WHERE), mode(DEFAULT_MODE);
ASG_WHILE: WHILE -> type(WHILE), mode(DEFAULT_MODE);
ASG_RESERVED_KEYWORD: RESERVED_KEYWORD -> type(RESERVED_KEYWORD), mode(DEFAULT_MODE);
ASG_DERIVE: DERIVE -> type(DERIVE), mode(DEFAULT_MODE);
ASG_COPY: COPY -> type(COPY), mode(DEFAULT_MODE);
ASG_CLONE: CLONE -> type(CLONE), mode(DEFAULT_MODE);
ASG_PARTIAL_EQ: PARTIAL_EQ -> type(PARTIAL_EQ), mode(DEFAULT_MODE);
ASG_EQ: EQ -> type(EQ), mode(DEFAULT_MODE);
ASG_UNDERSCORE: UNDERSCORE -> type(UNDERSCORE), mode(DEFAULT_MODE);
ASG_IDENTIFIER: IDENTIFIER -> type(IDENTIFIER), mode(DEFAULT_MODE);
ASG_INVALID_LIFETIME: INVALID_LIFETIME -> type(INVALID_LIFETIME), mode(DEFAULT_MODE);
ASG_INVALID_CHARACTER_LITERAL: INVALID_CHARACTER_LITERAL -> type(INVALID_CHARACTER_LITERAL), mode(DEFAULT_MODE);
ASG_LIFETIME: LIFETIME -> type(LIFETIME), mode(DEFAULT_MODE);
ASG_INTEGER_LITERAL: INTEGER_LITERAL -> type(INTEGER_LITERAL), mode(DEFAULT_MODE);
ASG_INVALID_NUMBER: INVALID_NUMBER -> type(INVALID_NUMBER), mode(DEFAULT_MODE);
ASG_LT: LT -> type(LT), mode(DEFAULT_MODE);
ASG_LE: LE -> type(LE), mode(DEFAULT_MODE);
ASG_NE: NE -> type(NE), mode(DEFAULT_MODE);
ASG_ANDAND: ANDAND -> type(ANDAND), mode(DEFAULT_MODE);
ASG_OROR: OROR -> type(OROR), mode(DEFAULT_MODE);
ASG_NOT: NOT -> type(NOT), mode(DEFAULT_MODE);
ASG_PLUS: PLUS -> type(PLUS), mode(DEFAULT_MODE);
ASG_MINUS: MINUS -> type(MINUS), mode(DEFAULT_MODE);
ASG_STAR: STAR -> type(STAR), mode(DEFAULT_MODE);
ASG_SLASH: SLASH -> type(SLASH), mode(DEFAULT_MODE);
ASG_PERCENT: PERCENT -> type(PERCENT), mode(DEFAULT_MODE);
ASG_CARET: CARET -> type(CARET), mode(DEFAULT_MODE);
ASG_AMP: AMP -> type(AMP), mode(DEFAULT_MODE);
ASG_PIPE: PIPE -> type(PIPE), mode(DEFAULT_MODE);
ASG_SHL: SHL -> type(SHL), mode(DEFAULT_MODE);
ASG_PLUS_ASSIGN: PLUS_ASSIGN -> type(PLUS_ASSIGN), mode(DEFAULT_MODE);
ASG_MINUS_ASSIGN: MINUS_ASSIGN -> type(MINUS_ASSIGN), mode(DEFAULT_MODE);
ASG_STAR_ASSIGN: STAR_ASSIGN -> type(STAR_ASSIGN), mode(DEFAULT_MODE);
ASG_SLASH_ASSIGN: SLASH_ASSIGN -> type(SLASH_ASSIGN), mode(DEFAULT_MODE);
ASG_PERCENT_ASSIGN: PERCENT_ASSIGN -> type(PERCENT_ASSIGN), mode(DEFAULT_MODE);
ASG_CARET_ASSIGN: CARET_ASSIGN -> type(CARET_ASSIGN), mode(DEFAULT_MODE);
ASG_AMP_ASSIGN: AMP_ASSIGN -> type(AMP_ASSIGN), mode(DEFAULT_MODE);
ASG_PIPE_ASSIGN: PIPE_ASSIGN -> type(PIPE_ASSIGN), mode(DEFAULT_MODE);
ASG_SHL_ASSIGN: SHL_ASSIGN -> type(SHL_ASSIGN), mode(DEFAULT_MODE);
ASG_DOT: DOT -> type(DOT), mode(DEFAULT_MODE);
ASG_COMMA: COMMA -> type(COMMA), mode(DEFAULT_MODE);
ASG_SEMI: SEMI -> type(SEMI), mode(DEFAULT_MODE);
ASG_COLON: COLON -> type(COLON), mode(DEFAULT_MODE);
ASG_PATHSEP: PATHSEP -> type(PATHSEP), mode(DEFAULT_MODE);
ASG_ARROW: ARROW -> type(ARROW), mode(DEFAULT_MODE);
ASG_HASH: HASH -> type(HASH), mode(DEFAULT_MODE);
ASG_LBRACE: LBRACE -> type(LBRACE), mode(DEFAULT_MODE);
ASG_RBRACE: RBRACE -> type(RBRACE), mode(DEFAULT_MODE);
ASG_LBRACKET: LBRACKET -> type(LBRACKET), mode(DEFAULT_MODE);
ASG_RBRACKET: RBRACKET -> type(RBRACKET), mode(DEFAULT_MODE);
ASG_LPAREN: LPAREN -> type(LPAREN), mode(DEFAULT_MODE);
ASG_RPAREN: RPAREN -> type(RPAREN), mode(DEFAULT_MODE);
ASG_WHITESPACE: WHITESPACE -> type(WHITESPACE), channel(HIDDEN), mode(DEFAULT_MODE);
ASG_LINE_COMMENT: LINE_COMMENT -> type(LINE_COMMENT), channel(HIDDEN), mode(DEFAULT_MODE);
ASG_BLOCK_COMMENT: BLOCK_COMMENT -> type(BLOCK_COMMENT), channel(HIDDEN), mode(DEFAULT_MODE);
ASG_UNTERMINATED_BLOCK_COMMENT: UNTERMINATED_BLOCK_COMMENT -> type(UNTERMINATED_BLOCK_COMMENT), mode(DEFAULT_MODE);
ASG_ERROR_CHAR: ERROR_CHAR -> type(ERROR_CHAR), mode(DEFAULT_MODE);
