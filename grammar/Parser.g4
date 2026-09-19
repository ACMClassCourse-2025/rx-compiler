// Rx course language. Entry point: crate. ANTLR 4.13.2; any target language.
// Read README.md for token conventions, precedence, and block tails.
parser grammar Parser;

options { tokenVocab=Lexer; }

crate
    : item* EOF
    ;

item
    : useDeclaration
    | functionDefinition
    | structDefinition
    | constantItem
    | inherentImpl
    ;

useDeclaration
    : USE useTree SEMI
    ;

useTree
    : (usePath? PATHSEP)? (STAR | LBRACE (useTree (COMMA useTree)* COMMA?)? RBRACE)
    | usePath (AS (identifier | UNDERSCORE))?
    ;

usePath
    : PATHSEP? usePathSegment (PATHSEP usePathSegment)*
    ;

usePathSegment
    : identifier | SELF_VALUE | SUPER | CRATE
    ;

functionDefinition
    : FN identifier genericParams? LPAREN functionParameters? RPAREN
      (ARROW typeRef)? whereClause? blockExpression
    ;

functionParameters
    : selfParam (COMMA functionParam)* COMMA?
    | functionParam (COMMA functionParam)* COMMA?
    ;

selfParam
    : (AMP lifetime?)? MUT? SELF_VALUE
    ;

functionParam
    : identifierBinding COLON typeRef
    ;

structDefinition
    : outerAttribute* STRUCT identifier genericParams? whereClause?
      LBRACE (structField (COMMA structField)* COMMA?)? RBRACE
    ;

structField
    : identifier COLON typeRef
    ;

outerAttribute
    : HASH LBRACKET DERIVE LPAREN (deriveName (COMMA deriveName)* COMMA?)?
      RPAREN RBRACKET
    ;

deriveName
    : COPY | CLONE | PARTIAL_EQ | EQ
    ;

constantItem
    : CONST identifier COLON typeRef equalsSign constValue SEMI
    ;

inherentImpl
    : IMPL genericParams? typeRef whereClause? LBRACE associatedItem* RBRACE
    ;

associatedItem
    : constantItem | functionDefinition
    ;

genericParams
    : LT (lifetimeParam (COMMA lifetimeParam)* COMMA?)? genericClose
    ;

lifetimeParam
    : lifetime (COLON lifetimeBounds)?
    ;

lifetime
    : LIFETIME
    ;

lifetimeBounds
    : (lifetime PLUS)* lifetime?
    ;

typeParamBounds
    : lifetime (PLUS lifetime)* PLUS?
    ;

whereClause
    : WHERE (whereClauseItem (COMMA whereClauseItem)* COMMA?)?
    ;

whereClauseItem
    : lifetime COLON lifetimeBounds
    | typeRef COLON typeParamBounds?
    ;

typeRef
    : LPAREN typeRef RPAREN
    | LPAREN RPAREN
    | typePath
    | referenceType
    | arrayType
    ;

referenceType
    // ANDAND constructs TWO references; lifetime/MUT belong to the inner one.
    : (AMP | ANDAND) lifetime? MUT? typeRef
    ;

arrayType
    : LBRACKET typeRef SEMI constValue RBRACKET
    ;

typePath
    : typePathSegment (PATHSEP typePathSegment)*
    ;

typePathSegment
    : pathIdentSegment (PATHSEP? genericArgs)?
    ;

pathInExpression
    : pathExprSegment (PATHSEP pathExprSegment)*
    ;

pathExprSegment
    : pathIdentSegment (PATHSEP genericArgs)?
    ;

pathIdentSegment
    : identifier | SELF_VALUE | SELF_TYPE
    ;

genericArgs
    : LT (genericArg (COMMA genericArg)* COMMA?)? genericClose
    ;

genericArg
    : lifetime | typeRef
    ;

genericClose
    : GT | GT_SECOND
    ;

// A cast ending in one of these types can be followed by < or <<. A bare
// final type-path segment instead interprets < as the start of type arguments.
closedCastType
    : LPAREN typeRef? RPAREN
    | arrayType
    | (AMP | ANDAND) lifetime? MUT? closedCastType
    | (typePathSegment PATHSEP)* pathIdentSegment PATHSEP? genericArgs
    ;

constValue
    : INTEGER_LITERAL
    | TRUE
    | FALSE
    | pathInExpression
    | MINUS magnitude
    | LPAREN constValue RPAREN
    ;

magnitude
    : INTEGER_LITERAL | pathInExpression | LPAREN magnitude RPAREN
    ;

identifierBinding
    : MUT? identifier
    ;

letStatement
    : LET identifierBinding (COLON typeRef)? equalsSign expression SEMI
    ;

blockExpression
    : LBRACE statement* statementExpression? RBRACE
    ;

statement
    : SEMI
    | letStatement
    | expressionWithBlock SEMI?
    | statementExpression SEMI
    ;

expressionWithBlock
    : blockExpression
    | ifExpression
    | LOOP blockExpression
    | WHILE conditionExpression blockExpression
    ;

ifExpression
    : IF conditionExpression blockExpression
      (ELSE (blockExpression | ifExpression))?
    ;

// Ordinary value expressions. Repeated binary operators are left folds;
// assignment recurses on the right. The closed* alternatives constrain the
// final cast type before < or << (see closedCastType and README.md).
expression
    : assignmentExpression
    ;

assignmentExpression
    : logicalOrExpression (assignmentOperator expression)?
    ;

logicalOrExpression
    : logicalAndExpression (OROR logicalAndExpression)*
    ;

logicalAndExpression
    : comparisonExpression (ANDAND comparisonExpression)*
    ;

comparisonExpression
    : bitOrExpression (comparisonExceptLt bitOrExpression)?
    | closedBitOrExpression LT bitOrExpression
    ;

bitOrExpression
    : bitXorExpression (PIPE bitXorExpression)*
    ;

closedBitOrExpression
    : (bitXorExpression PIPE)* closedBitXorExpression
    ;

bitXorExpression
    : bitAndExpression (CARET bitAndExpression)*
    ;

closedBitXorExpression
    : (bitAndExpression CARET)* closedBitAndExpression
    ;

bitAndExpression
    : shiftExpression (AMP shiftExpression)*
    ;

closedBitAndExpression
    : (shiftExpression AMP)* closedShiftExpression
    ;

shiftExpression
    : (closedAdditiveExpression SHL | additiveExpression shiftRight)* additiveExpression
    ;

closedShiftExpression
    : (closedAdditiveExpression SHL | additiveExpression shiftRight)* closedAdditiveExpression
    ;

additiveExpression
    : multiplicativeExpression (additiveOperator multiplicativeExpression)*
    ;

closedAdditiveExpression
    : (multiplicativeExpression additiveOperator)* closedMultiplicativeExpression
    ;

multiplicativeExpression
    : castExpression (multiplicativeOperator castExpression)*
    ;

closedMultiplicativeExpression
    : (castExpression multiplicativeOperator)* closedCastExpression
    ;

castExpression
    : unaryExpression (AS typeRef)*
    ;

closedCastExpression
    : unaryExpression
    | castExpression AS closedCastType
    ;

unaryExpression
    : unaryOperator unaryExpression
    | postfixExpression
    ;

postfixExpression
    : primaryExpression postfixSuffix*
    ;

// Condition expressions: no undelimited struct construction.
conditionExpression
    : conditionAssignmentExpression
    ;

conditionAssignmentExpression
    : conditionLogicalOrExpression (assignmentOperator conditionExpression)?
    ;

conditionLogicalOrExpression
    : conditionLogicalAndExpression (OROR conditionLogicalAndExpression)*
    ;

conditionLogicalAndExpression
    : conditionComparisonExpression (ANDAND conditionComparisonExpression)*
    ;

conditionComparisonExpression
    : conditionBitOrExpression (comparisonExceptLt conditionBitOrExpression)?
    | conditionClosedBitOrExpression LT conditionBitOrExpression
    ;

conditionBitOrExpression
    : conditionBitXorExpression (PIPE conditionBitXorExpression)*
    ;

conditionClosedBitOrExpression
    : (conditionBitXorExpression PIPE)* conditionClosedBitXorExpression
    ;

conditionBitXorExpression
    : conditionBitAndExpression (CARET conditionBitAndExpression)*
    ;

conditionClosedBitXorExpression
    : (conditionBitAndExpression CARET)* conditionClosedBitAndExpression
    ;

conditionBitAndExpression
    : conditionShiftExpression (AMP conditionShiftExpression)*
    ;

conditionClosedBitAndExpression
    : (conditionShiftExpression AMP)* conditionClosedShiftExpression
    ;

conditionShiftExpression
    : (conditionClosedAdditiveExpression SHL | conditionAdditiveExpression shiftRight)* conditionAdditiveExpression
    ;

conditionClosedShiftExpression
    : (conditionClosedAdditiveExpression SHL | conditionAdditiveExpression shiftRight)* conditionClosedAdditiveExpression
    ;

conditionAdditiveExpression
    : conditionMultiplicativeExpression (additiveOperator conditionMultiplicativeExpression)*
    ;

conditionClosedAdditiveExpression
    : (conditionMultiplicativeExpression additiveOperator)* conditionClosedMultiplicativeExpression
    ;

conditionMultiplicativeExpression
    : conditionCastExpression (multiplicativeOperator conditionCastExpression)*
    ;

conditionClosedMultiplicativeExpression
    : (conditionCastExpression multiplicativeOperator)* conditionClosedCastExpression
    ;

conditionCastExpression
    : conditionUnaryExpression (AS typeRef)*
    ;

conditionClosedCastExpression
    : conditionUnaryExpression
    | conditionCastExpression AS closedCastType
    ;

conditionUnaryExpression
    : unaryOperator conditionUnaryExpression
    | conditionPostfixExpression
    ;

conditionPostfixExpression
    : conditionPrimary postfixSuffix*
    ;

// Break operands in conditions: the first primary cannot be a bare block.
// Subsequent operands use the ordinary condition rules.
conditionBreakExpression
    : conditionBreakAssignmentExpression
    ;

conditionBreakAssignmentExpression
    : conditionBreakLogicalOrExpression (assignmentOperator conditionExpression)?
    ;

conditionBreakLogicalOrExpression
    : conditionBreakLogicalAndExpression (OROR conditionLogicalAndExpression)*
    ;

conditionBreakLogicalAndExpression
    : conditionBreakComparisonExpression (ANDAND conditionComparisonExpression)*
    ;

conditionBreakComparisonExpression
    : conditionBreakBitOrExpression (comparisonExceptLt conditionBitOrExpression)?
    | conditionBreakClosedBitOrExpression LT conditionBitOrExpression
    ;

conditionBreakBitOrExpression
    : conditionBreakBitXorExpression (PIPE conditionBitXorExpression)*
    ;

conditionBreakClosedBitOrExpression
    : conditionBreakClosedBitXorExpression
    | conditionBreakBitXorExpression PIPE (conditionBitXorExpression PIPE)* conditionClosedBitXorExpression
    ;

conditionBreakBitXorExpression
    : conditionBreakBitAndExpression (CARET conditionBitAndExpression)*
    ;

conditionBreakClosedBitXorExpression
    : conditionBreakClosedBitAndExpression
    | conditionBreakBitAndExpression CARET (conditionBitAndExpression CARET)* conditionClosedBitAndExpression
    ;

conditionBreakBitAndExpression
    : conditionBreakShiftExpression (AMP conditionShiftExpression)*
    ;

conditionBreakClosedBitAndExpression
    : conditionBreakClosedShiftExpression
    | conditionBreakShiftExpression AMP (conditionShiftExpression AMP)* conditionClosedShiftExpression
    ;

conditionBreakShiftExpression
    : conditionBreakAdditiveExpression
    | (conditionBreakClosedAdditiveExpression SHL | conditionBreakAdditiveExpression shiftRight)
      (conditionClosedAdditiveExpression SHL | conditionAdditiveExpression shiftRight)* conditionAdditiveExpression
    ;

conditionBreakClosedShiftExpression
    : conditionBreakClosedAdditiveExpression
    | (conditionBreakClosedAdditiveExpression SHL | conditionBreakAdditiveExpression shiftRight)
      (conditionClosedAdditiveExpression SHL | conditionAdditiveExpression shiftRight)* conditionClosedAdditiveExpression
    ;

conditionBreakAdditiveExpression
    : conditionBreakMultiplicativeExpression (additiveOperator conditionMultiplicativeExpression)*
    ;

conditionBreakClosedAdditiveExpression
    : conditionBreakClosedMultiplicativeExpression
    | conditionBreakMultiplicativeExpression additiveOperator
      (conditionMultiplicativeExpression additiveOperator)* conditionClosedMultiplicativeExpression
    ;

conditionBreakMultiplicativeExpression
    : conditionBreakCastExpression (multiplicativeOperator conditionCastExpression)*
    ;

conditionBreakClosedMultiplicativeExpression
    : conditionBreakClosedCastExpression
    | conditionBreakCastExpression multiplicativeOperator
      (conditionCastExpression multiplicativeOperator)* conditionClosedCastExpression
    ;

conditionBreakCastExpression
    : conditionBreakUnaryExpression (AS typeRef)*
    ;

conditionBreakClosedCastExpression
    : conditionBreakUnaryExpression
    | conditionBreakCastExpression AS closedCastType
    ;

conditionBreakUnaryExpression
    : unaryOperator conditionUnaryExpression
    | conditionBreakPostfixExpression
    ;

conditionBreakPostfixExpression
    : conditionPrimaryWithoutBareBlock postfixSuffix*
    ;

// Statement starts: a leading block continues only through a dot suffix.
statementExpression
    : statementAssignmentExpression
    ;

statementAssignmentExpression
    : statementLogicalOrExpression (assignmentOperator expression)?
    ;

statementLogicalOrExpression
    : statementLogicalAndExpression (OROR logicalAndExpression)*
    ;

statementLogicalAndExpression
    : statementComparisonExpression (ANDAND comparisonExpression)*
    ;

statementComparisonExpression
    : statementBitOrExpression (comparisonExceptLt bitOrExpression)?
    | statementClosedBitOrExpression LT bitOrExpression
    ;

statementBitOrExpression
    : statementBitXorExpression (PIPE bitXorExpression)*
    ;

statementClosedBitOrExpression
    : statementClosedBitXorExpression
    | statementBitXorExpression PIPE (bitXorExpression PIPE)* closedBitXorExpression
    ;

statementBitXorExpression
    : statementBitAndExpression (CARET bitAndExpression)*
    ;

statementClosedBitXorExpression
    : statementClosedBitAndExpression
    | statementBitAndExpression CARET (bitAndExpression CARET)* closedBitAndExpression
    ;

statementBitAndExpression
    : statementShiftExpression (AMP shiftExpression)*
    ;

statementClosedBitAndExpression
    : statementClosedShiftExpression
    | statementShiftExpression AMP (shiftExpression AMP)* closedShiftExpression
    ;

statementShiftExpression
    : statementAdditiveExpression
    | (statementClosedAdditiveExpression SHL | statementAdditiveExpression shiftRight)
      (closedAdditiveExpression SHL | additiveExpression shiftRight)* additiveExpression
    ;

statementClosedShiftExpression
    : statementClosedAdditiveExpression
    | (statementClosedAdditiveExpression SHL | statementAdditiveExpression shiftRight)
      (closedAdditiveExpression SHL | additiveExpression shiftRight)* closedAdditiveExpression
    ;

statementAdditiveExpression
    : statementMultiplicativeExpression (additiveOperator multiplicativeExpression)*
    ;

statementClosedAdditiveExpression
    : statementClosedMultiplicativeExpression
    | statementMultiplicativeExpression additiveOperator
      (multiplicativeExpression additiveOperator)* closedMultiplicativeExpression
    ;

statementMultiplicativeExpression
    : statementCastExpression (multiplicativeOperator castExpression)*
    ;

statementClosedMultiplicativeExpression
    : statementClosedCastExpression
    | statementCastExpression multiplicativeOperator
      (castExpression multiplicativeOperator)* closedCastExpression
    ;

statementCastExpression
    : statementUnaryExpression (AS typeRef)*
    ;

statementClosedCastExpression
    : statementUnaryExpression
    | statementCastExpression AS closedCastType
    ;

statementUnaryExpression
    : unaryOperator unaryExpression
    | statementPostfixExpression
    ;

statementPostfixExpression
    : nonBlockPrimary postfixSuffix*
    | expressionWithBlock dotSuffix postfixSuffix*
    ;


primaryExpression
    : nonBlockPrimary
    | expressionWithBlock
    ;

nonBlockPrimary
    : literalExpression
    | pathInExpression (LBRACE structExprFields? RBRACE)?
    | LPAREN expression? RPAREN
    | arrayExpression
    | BREAK expression?
    | RETURN expression?
    | CONTINUE
    ;

// Parentheses, argument lists, indices, arrays, and block bodies establish
// their own delimiters and use unrestricted expressions inside a condition.
conditionPrimary
    : conditionPrimaryWithoutBareBlock
    | blockExpression
    ;

// A break operand at a condition boundary may not start with a bare block.
// All other operands remain greedy, including -x, &&x, and parenthesized x.
conditionPrimaryWithoutBareBlock
    : literalExpression
    | pathInExpression
    | LPAREN expression? RPAREN
    | arrayExpression
    | ifExpression
    | LOOP blockExpression
    | WHILE conditionExpression blockExpression
    | BREAK conditionBreakExpression?
    | RETURN conditionExpression?
    | CONTINUE
    ;

literalExpression
    : INTEGER_LITERAL | TRUE | FALSE
    ;

structExprFields
    : structExprField (COMMA structExprField)* COMMA?
    ;

structExprField
    : identifier COLON expression
    ;

arrayExpression
    : LBRACKET (expression (SEMI constValue | (COMMA expression)* COMMA?))? RBRACKET
    ;

postfixSuffix
    : callArguments
    | LBRACKET expression RBRACKET
    | dotSuffix
    ;

dotSuffix
    : DOT pathExprSegment callArguments
    | DOT identifier
    ;

callArguments
    : LPAREN (expression (COMMA expression)* COMMA?)? RPAREN
    ;

unaryOperator
    : MINUS | NOT | STAR | (AMP | ANDAND) MUT?
    ;

multiplicativeOperator
    : STAR | SLASH | PERCENT
    ;

additiveOperator
    : PLUS | MINUS
    ;

// Lexer modes distinguish the pieces of a single maximal punctuation token.
// Pieces from separate tokens, even adjacent tokens, cannot form an operator.
shiftRight
    : GT GT_SECOND
    ;

comparisonExceptLt
    : EQEQ | NE | LE | GT GE_EQ | GT_SECOND SHR_EQ | genericClose
    ;

assignmentOperator
    : equalsSign | PLUS_ASSIGN | MINUS_ASSIGN | STAR_ASSIGN | SLASH_ASSIGN
    | PERCENT_ASSIGN | AMP_ASSIGN | PIPE_ASSIGN | CARET_ASSIGN
    | SHL_ASSIGN | GT GT_SECOND SHR_EQ
    ;

equalsSign
    : ASSIGN | GE_EQ | SHR_EQ
    ;

// Attribute names are contextual, NOT reserved identifiers.
identifier
    : IDENTIFIER | DERIVE | COPY | CLONE | PARTIAL_EQ | EQ
    ;
