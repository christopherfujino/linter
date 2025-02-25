// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../analyzer.dart';

const _desc = "Don't use `final` for local variables.";

const _details = r'''
Use `var`, not `final`, when declaring local variables.

Per [Effective Dart](https://dart.dev/guides/language/effective-dart/usage#do-follow-a-consistent-rule-for-var-and-final-on-local-variables),
there are two styles in wide use. This rule enforces the `var` style.
For the alternative style that prefers `final`, enable `prefer_final_locals`
and `prefer_final_in_for_each` instead.

For fields, `final` is always recommended; see the rule `prefer_final_fields`.

**BAD:**
```dart
void badMethod() {
  final label = 'Final or var?';
  for (final char in ['v', 'a', 'r']) {
    print(char);
  }
}
```

**GOOD:**
```dart
void goodMethod() {
  var label = 'Final or var?';
  for (var char in ['v', 'a', 'r']) {
    print(char);
  }
}
```
''';

class UnnecessaryFinal extends LintRule {
  static const LintCode withType = LintCode(
      'unnecessary_final', "Local variables should not be marked as 'final'.",
      correctionMessage: "Remove the 'final'.");

  static const LintCode withoutType = LintCode(
      'unnecessary_final', "Local variables should not be marked as 'final'.",
      correctionMessage: "Replace 'final' with 'var'.");

  UnnecessaryFinal()
      : super(
            name: 'unnecessary_final',
            description: _desc,
            details: _details,
            group: Group.style);

  @override
  List<String> get incompatibleRules =>
      const ['prefer_final_locals', 'prefer_final_parameters'];

  @override
  List<LintCode> get lintCodes => [withType, withoutType];

  @override
  void registerNodeProcessors(
      NodeLintRegistry registry, LinterContext context) {
    var visitor = _Visitor(this);
    registry
      ..addFormalParameterList(this, visitor)
      ..addForStatement(this, visitor)
      ..addVariableDeclarationStatement(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final LintRule rule;

  _Visitor(this.rule);

  @override
  void visitFormalParameterList(FormalParameterList parameterList) {
    for (var node in parameterList.parameters) {
      if (node.isFinal) {
        var keyword = _getFinal(node);
        if (keyword == null) {
          continue;
        }
        var type = _getType(node);
        var errorCode = type == null
            ? UnnecessaryFinal.withoutType
            : UnnecessaryFinal.withType;
        rule.reportLintForToken(keyword, errorCode: errorCode);
      }
    }
  }

  @override
  void visitForStatement(ForStatement node) {
    var forLoopParts = node.forLoopParts;
    // If the following `if` test fails, then either the statement is not a
    // for-each loop, or it is something like `for(a in b) { ... }`.  In the
    // second case, notice `a` is not actually declared from within the
    // loop. `a` is a variable declared outside the loop.
    if (forLoopParts is ForEachPartsWithDeclaration) {
      var loopVariable = forLoopParts.loopVariable;

      if (loopVariable.isFinal) {
        var errorCode = loopVariable.type == null
            ? UnnecessaryFinal.withoutType
            : UnnecessaryFinal.withType;
        rule.reportLintForToken(loopVariable.keyword, errorCode: errorCode);
      }
    }
  }

  @override
  void visitVariableDeclarationStatement(VariableDeclarationStatement node) {
    if (node.variables.isFinal) {
      var errorCode = node.variables.type == null
          ? UnnecessaryFinal.withoutType
          : UnnecessaryFinal.withType;
      rule.reportLintForToken(node.variables.keyword, errorCode: errorCode);
    }
  }

  /// Return the `final` token for the parameter [node].
  Token? _getFinal(FormalParameter node) {
    // TODO(brianwilkerson) Combine with `_getType` by using a record to hold
    //  the token and type.
    var parameter = node is DefaultFormalParameter ? node.parameter : node;
    if (parameter is FieldFormalParameter) {
      return parameter.keyword;
    } else if (parameter is SimpleFormalParameter) {
      return parameter.keyword;
    } else if (parameter is SuperFormalParameter) {
      return parameter.keyword;
    }
    return null;
  }

  /// Return the type of the formal parameter [node], or `null` if there is no
  /// explicit type.
  AstNode? _getType(FormalParameter node) {
    var parameter = node is DefaultFormalParameter ? node.parameter : node;
    if (parameter is FieldFormalParameter) {
      return parameter.type;
    } else if (parameter is SimpleFormalParameter) {
      return parameter.type;
    } else if (parameter is SuperFormalParameter) {
      return parameter.type;
    }
    return null;
  }
}
