# Droplet ANTLR adapter
#
# Copyright (c) 2015 Anthony Bau (dab1998@gmail.com)
# MIT License

helper = require './helper.coffee'
model = require './model.coffee'
parser = require './parser.coffee'
treewalk = require './treewalk.coffee'
antlr4 = require 'antlr4'

ANTLR_PARSER_COLLECTION = {
  'JavaLexer': require('../antlr/JavaLexer'),
  'JavaParser': require('../antlr/JavaParser'),
  'CLexer': require('../antlr/CLexer'),
  'CParser': require('../antlr/CParser'),
  'CPP14Lexer': require('../antlr/CPP14Lexer'),
  'CPP14Parser': require('../antlr/CPP14Parser'),
  'jvmBasicLexer': require('../antlr/jvmBasicLexer'),
  'jvmBasicParser': require('../antlr/jvmBasicParser'),
}

exports.createANTLRParser = (name, config, root) ->
  root ?= 'compilationUnit'

  parse = (context, text) ->
    # Construct but do not execute all of the necessary ANTLR accessories
    chars = new antlr4.InputStream(text)
    lexer = new ANTLR_PARSER_COLLECTION["#{name}Lexer"]["#{name}Lexer"](chars)
    tokens = new antlr4.CommonTokenStream(lexer)
    parser = new ANTLR_PARSER_COLLECTION["#{name}Parser"]["#{name}Parser"](tokens)

    parser._errHandler = new antlr4.error.BailErrorStrategy()

    # Build the actual parse tree
    parser.buildParseTrees = true
    return transform parser[context + '_DropletFile']()

  # Transform an ANTLR tree into a treewalker-type tree
  transform = (node, parent = null) ->
    result = {}
    if node.children?
      result.terminal = node.children.length is 0
      result.type = node.parser.ruleNames[node.ruleIndex]
      result.children = (transform(child, result) for child in node.children)
      result.bounds = getBounds node
      result.parent = parent
    else
      result.terminal = true
      result.children = []
      result.bounds = getBounds node
      result.parent = parent
      if node.symbol?
        result.type = (node.parser ? node.parentCtx.parser).symbolicNames[node.symbol.type]
        result.data = {text: node.symbol.text}
      else
        result.type = node.parser.ruleNames[node.ruleIndex]
        result.data = {}
    if result.type? and result.type[-'_DropletFile'.length...] is '_DropletFile'
      result.type = result.type[...-'_DropletFile'.length]
      result.children.pop()

    return result

  getBounds = (node) ->
    if node.start? and node.stop?
      return {
        start: {
          line: node.start.line - 1
          column: node.start.column
        }
        end: {
          line: node.stop.line - 1
          column: node.stop.column + node.stop.stop - node.stop.start + 1
        }
      }
    else if node.start? and not node.symbol?
      return {
        start: {
          line: node.start.line - 1
          column: node.start.column
        }
        end: {
          line: node.start.line - 1
          column: node.start.column
        }
      }
    else
      return {
        start: {
          line: node.symbol.line - 1
          column: node.symbol.column
        }
        end: {
          line: node.symbol.line - 1
          column: node.symbol.column + node.symbol.stop - node.symbol.start + 1
        }
      }

  return treewalk.createTreewalkParser parse, config, root
