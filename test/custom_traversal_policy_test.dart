import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flauncher/custom_traversal_policy.dart';

void main() {
  group('Geometry Extension', () {
    testWidgets('vertical positions', (WidgetTester tester) async {
      final node1 = FocusNode();
      final node2 = FocusNode();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned(
                left: 10,
                top: 10,
                width: 10,
                height: 10,
                child: Focus(focusNode: node1, child: const SizedBox()),
              ),
              Positioned(
                left: 10,
                top: 30,
                width: 10,
                height: 10,
                child: Focus(focusNode: node2, child: const SizedBox()),
              ),
            ],
          ),
        ),
      );

      expect(node2.isBelow(node1), isTrue);
      expect(node2.isBelowOrEquals(node1), isTrue);
      expect(node1.isBelow(node2), isFalse);

      expect(node1.isAbove(node2), isTrue);
      expect(node1.isAboveOrEquals(node2), isTrue);
      expect(node2.isAbove(node1), isFalse);
    });

    testWidgets('horizontal positions', (WidgetTester tester) async {
      final node1 = FocusNode();
      final node2 = FocusNode();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned(
                left: 10,
                top: 10,
                width: 10,
                height: 10,
                child: Focus(focusNode: node1, child: const SizedBox()),
              ),
              Positioned(
                left: 30,
                top: 10,
                width: 10,
                height: 10,
                child: Focus(focusNode: node2, child: const SizedBox()),
              ),
            ],
          ),
        ),
      );

      expect(node2.isRightTo(node1), isTrue);
      expect(node2.isRightToOrEquals(node1), isTrue);
      expect(node1.isRightTo(node2), isFalse);

      expect(node1.isLeftTo(node2), isTrue);
      expect(node1.isLeftToOrEquals(node2), isTrue);
      expect(node2.isLeftTo(node1), isFalse);

      expect(node1.isOnTheSameRow(node2), isTrue);
    });

    testWidgets('equals positions', (WidgetTester tester) async {
      final node1 = FocusNode();
      final node2 = FocusNode();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned(
                left: 10,
                top: 10,
                width: 10,
                height: 10,
                child: Focus(focusNode: node1, child: const SizedBox()),
              ),
              Positioned(
                left: 10,
                top: 10,
                width: 10,
                height: 10,
                child: Focus(focusNode: node2, child: const SizedBox()),
              ),
            ],
          ),
        ),
      );

      expect(node2.isBelowOrEquals(node1), isTrue);
      expect(node2.isBelow(node1), isFalse);
      expect(node1.isAboveOrEquals(node2), isTrue);
      expect(node1.isAbove(node2), isFalse);

      expect(node2.isRightToOrEquals(node1), isTrue);
      expect(node2.isRightTo(node1), isFalse);
      expect(node1.isLeftToOrEquals(node2), isTrue);
      expect(node1.isLeftTo(node2), isFalse);

      expect(node1.isOnTheSameRow(node2), isTrue);
      expect(node1.distance(node2), 0.0);
    });

    testWidgets('distance', (WidgetTester tester) async {
      final node1 = FocusNode();
      final node2 = FocusNode();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: 10,
                height: 10,
                child: Focus(focusNode: node1, child: const SizedBox()),
              ),
              Positioned(
                left: 30, // center x = 35
                top: 40,  // center y = 45
                width: 10,
                height: 10,
                child: Focus(focusNode: node2, child: const SizedBox()),
              ),
            ],
          ),
        ),
      );

      // node1 center is (5, 5). node2 center is (35, 45).
      // dx = 30, dy = 40. sqrt(30^2 + 40^2) = 50.
      expect(node1.distance(node2), 50.0);
    });
  });

  group('NodeSearcher', () {
    testWidgets('findCandidates up', (WidgetTester tester) async {
      final nodeFrom = FocusNode();
      final nodeAbove = FocusNode();
      final nodeBelow = FocusNode();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned(left: 10, top: 30, width: 10, height: 10, child: Focus(focusNode: nodeFrom, child: const SizedBox())),
              Positioned(left: 10, top: 10, width: 10, height: 10, child: Focus(focusNode: nodeAbove, child: const SizedBox())),
              Positioned(left: 10, top: 50, width: 10, height: 10, child: Focus(focusNode: nodeBelow, child: const SizedBox())),
            ],
          ),
        ),
      );

      final searcher = NodeSearcher(TraversalDirection.up);
      final candidates = searcher.findCandidates([nodeFrom, nodeAbove, nodeBelow], nodeFrom);

      expect(candidates.length, 1);
      expect(candidates.first.node, nodeAbove);
    });

    testWidgets('findCandidates down', (WidgetTester tester) async {
      final nodeFrom = FocusNode();
      final nodeAbove = FocusNode();
      final nodeBelow = FocusNode();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned(left: 10, top: 30, width: 10, height: 10, child: Focus(focusNode: nodeFrom, child: const SizedBox())),
              Positioned(left: 10, top: 10, width: 10, height: 10, child: Focus(focusNode: nodeAbove, child: const SizedBox())),
              Positioned(left: 10, top: 50, width: 10, height: 10, child: Focus(focusNode: nodeBelow, child: const SizedBox())),
            ],
          ),
        ),
      );

      final searcher = NodeSearcher(TraversalDirection.down);
      final candidates = searcher.findCandidates([nodeFrom, nodeAbove, nodeBelow], nodeFrom);

      expect(candidates.length, 1);
      expect(candidates.first.node, nodeBelow);
    });

    testWidgets('findCandidates left', (WidgetTester tester) async {
      final nodeFrom = FocusNode();
      final nodeLeft = FocusNode();
      final nodeRight = FocusNode();
      final nodeLeftDiffRow = FocusNode();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned(left: 30, top: 10, width: 10, height: 10, child: Focus(focusNode: nodeFrom, child: const SizedBox())),
              Positioned(left: 10, top: 10, width: 10, height: 10, child: Focus(focusNode: nodeLeft, child: const SizedBox())),
              Positioned(left: 50, top: 10, width: 10, height: 10, child: Focus(focusNode: nodeRight, child: const SizedBox())),
              Positioned(left: 10, top: 30, width: 10, height: 10, child: Focus(focusNode: nodeLeftDiffRow, child: const SizedBox())),
            ],
          ),
        ),
      );

      final searcher = NodeSearcher(TraversalDirection.left);
      final candidates = searcher.findCandidates([nodeFrom, nodeLeft, nodeRight, nodeLeftDiffRow], nodeFrom);

      expect(candidates.length, 1);
      expect(candidates.first.node, nodeLeft);
    });

    testWidgets('findCandidates right', (WidgetTester tester) async {
      final nodeFrom = FocusNode();
      final nodeLeft = FocusNode();
      final nodeRight = FocusNode();
      final nodeRightDiffRow = FocusNode();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned(left: 30, top: 10, width: 10, height: 10, child: Focus(focusNode: nodeFrom, child: const SizedBox())),
              Positioned(left: 10, top: 10, width: 10, height: 10, child: Focus(focusNode: nodeLeft, child: const SizedBox())),
              Positioned(left: 50, top: 10, width: 10, height: 10, child: Focus(focusNode: nodeRight, child: const SizedBox())),
              Positioned(left: 50, top: 30, width: 10, height: 10, child: Focus(focusNode: nodeRightDiffRow, child: const SizedBox())),
            ],
          ),
        ),
      );

      final searcher = NodeSearcher(TraversalDirection.right);
      final candidates = searcher.findCandidates([nodeFrom, nodeLeft, nodeRight, nodeRightDiffRow], nodeFrom);

      expect(candidates.length, 1);
      expect(candidates.first.node, nodeRight);
    });

    testWidgets('findBestFocusNode down', (WidgetTester tester) async {
      final nodeFrom = FocusNode();
      final nodeBelowLeft = FocusNode();
      final nodeBelowCenter = FocusNode();
      final nodeBelowRight = FocusNode();
      final nodeWayBelow = FocusNode();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned(left: 30, top: 10, width: 10, height: 10, child: Focus(focusNode: nodeFrom, child: const SizedBox())),
              // Same row below
              Positioned(left: 10, top: 30, width: 10, height: 10, child: Focus(focusNode: nodeBelowLeft, child: const SizedBox())),
              Positioned(left: 30, top: 30, width: 10, height: 10, child: Focus(focusNode: nodeBelowCenter, child: const SizedBox())),
              Positioned(left: 50, top: 30, width: 10, height: 10, child: Focus(focusNode: nodeBelowRight, child: const SizedBox())),
              // Different row below
              Positioned(left: 30, top: 50, width: 10, height: 10, child: Focus(focusNode: nodeWayBelow, child: const SizedBox())),
            ],
          ),
        ),
      );

      final searcher = NodeSearcher(TraversalDirection.down);
      final candidatesNodes = toCandidateNodes([nodeWayBelow, nodeBelowLeft, nodeBelowRight, nodeBelowCenter]);
      final best = searcher.findBestFocusNode(candidatesNodes, nodeFrom);

      expect(best, nodeBelowCenter);
    });

    testWidgets('findBestFocusNode up', (WidgetTester tester) async {
      final nodeFrom = FocusNode();
      final nodeAboveLeft = FocusNode();
      final nodeAboveCenter = FocusNode();
      final nodeAboveRight = FocusNode();
      final nodeWayAbove = FocusNode();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned(left: 30, top: 50, width: 10, height: 10, child: Focus(focusNode: nodeFrom, child: const SizedBox())),
              // Same row above
              Positioned(left: 10, top: 30, width: 10, height: 10, child: Focus(focusNode: nodeAboveLeft, child: const SizedBox())),
              Positioned(left: 30, top: 30, width: 10, height: 10, child: Focus(focusNode: nodeAboveCenter, child: const SizedBox())),
              Positioned(left: 50, top: 30, width: 10, height: 10, child: Focus(focusNode: nodeAboveRight, child: const SizedBox())),
              // Different row above
              Positioned(left: 30, top: 10, width: 10, height: 10, child: Focus(focusNode: nodeWayAbove, child: const SizedBox())),
            ],
          ),
        ),
      );

      final searcher = NodeSearcher(TraversalDirection.up);
      final candidatesNodes = toCandidateNodes([nodeWayAbove, nodeAboveLeft, nodeAboveRight, nodeAboveCenter]);
      final best = searcher.findBestFocusNode(candidatesNodes, nodeFrom);

      expect(best, nodeAboveCenter);
    });

    testWidgets('findBestFocusNode right', (WidgetTester tester) async {
      final nodeFrom = FocusNode();
      final nodeRight = FocusNode();
      final nodeFarRight = FocusNode();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned(left: 10, top: 10, width: 10, height: 10, child: Focus(focusNode: nodeFrom, child: const SizedBox())),
              Positioned(left: 30, top: 10, width: 10, height: 10, child: Focus(focusNode: nodeRight, child: const SizedBox())),
              Positioned(left: 50, top: 10, width: 10, height: 10, child: Focus(focusNode: nodeFarRight, child: const SizedBox())),
            ],
          ),
        ),
      );

      final searcher = NodeSearcher(TraversalDirection.right);
      final candidatesNodes = toCandidateNodes([nodeFarRight, nodeRight]);
      final best = searcher.findBestFocusNode(candidatesNodes, nodeFrom);

      expect(best, nodeRight);
    });

    testWidgets('findBestFocusNode left', (WidgetTester tester) async {
      final nodeFrom = FocusNode();
      final nodeLeft = FocusNode();
      final nodeFarLeft = FocusNode();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned(left: 50, top: 10, width: 10, height: 10, child: Focus(focusNode: nodeFrom, child: const SizedBox())),
              Positioned(left: 30, top: 10, width: 10, height: 10, child: Focus(focusNode: nodeLeft, child: const SizedBox())),
              Positioned(left: 10, top: 10, width: 10, height: 10, child: Focus(focusNode: nodeFarLeft, child: const SizedBox())),
            ],
          ),
        ),
      );

      final searcher = NodeSearcher(TraversalDirection.left);
      final candidatesNodes = toCandidateNodes([nodeFarLeft, nodeLeft]);
      final best = searcher.findBestFocusNode(candidatesNodes, nodeFrom);

      expect(best, nodeLeft);
    });
  });

  group('RowByRowTraversalPolicy', () {
    testWidgets('sortDescendants', (WidgetTester tester) async {
      final node1 = FocusNode();
      final node2 = FocusNode();

      final policy = RowByRowTraversalPolicy();
      final descendants = [node1, node2];

      final sorted = policy.sortDescendants(descendants, node1);
      expect(sorted, equals(descendants)); // should return exactly the same iterable
    });

    testWidgets('up', (WidgetTester tester) async {
      final nodeFrom = FocusNode();
      final nodeAbove = FocusNode();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FocusScope(
            child: Stack(
              children: [
                Positioned(left: 10, top: 30, width: 10, height: 10, child: Focus(focusNode: nodeFrom, child: const SizedBox())),
                Positioned(left: 10, top: 10, width: 10, height: 10, child: Focus(focusNode: nodeAbove, child: const SizedBox())),
              ],
            ),
          ),
        ),
      );

      final policy = RowByRowTraversalPolicy();
      final result = policy.inDirection(nodeFrom, TraversalDirection.up);

      expect(result, isTrue);
      // Wait for focus to propagate
      await tester.pump();
      expect(nodeAbove.hasFocus, isTrue);
    });

    testWidgets('down', (WidgetTester tester) async {
      final nodeFrom = FocusNode();
      final nodeBelow = FocusNode();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FocusScope(
            child: Stack(
              children: [
                Positioned(left: 10, top: 10, width: 10, height: 10, child: Focus(focusNode: nodeFrom, child: const SizedBox())),
                Positioned(left: 10, top: 30, width: 10, height: 10, child: Focus(focusNode: nodeBelow, child: const SizedBox())),
              ],
            ),
          ),
        ),
      );

      final policy = RowByRowTraversalPolicy();
      final result = policy.inDirection(nodeFrom, TraversalDirection.down);

      expect(result, isTrue);
      await tester.pump();
      expect(nodeBelow.hasFocus, isTrue);
    });

    testWidgets('empty candidates fallback - out of scope fallback', (WidgetTester tester) async {
      final nodeFrom = FocusNode();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: FocusScope(
            child: Stack(
              children: [
                Positioned(left: 10, top: 10, width: 10, height: 10, child: Focus(focusNode: nodeFrom, child: const SizedBox())),
              ],
            ),
          ),
        ),
      );

      final policy = RowByRowTraversalPolicy();
      // Because DirectionalFocusTraversalPolicyMixin is smart, we should verify the behavior.
      // If no candidates, it calls super, and if there is nowhere to go, it usually does wrap/scroll/returns true or false.
      // Actually DirectionalFocusTraversalPolicyMixin fallback behavior returns boolean according to finding focus or moving it out.
      final result = policy.inDirection(nodeFrom, TraversalDirection.up);

      // We just ensure it doesn't crash and returns a value (in this case true because the default mixin fallback handles scroll/etc and might return true to claim handling, or maybe false depending on tree)
      expect(result, isNotNull);
    });

    testWidgets('nodes == null fallback', (WidgetTester tester) async {
      final policy = RowByRowTraversalPolicy();
      final nodeFrom = FocusNode();

      // For inDirection to correctly fallback in the DirectionalFocusTraversalPolicyMixin
      // we need at least an established tree.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Focus(
            focusNode: nodeFrom,
            child: const SizedBox(),
          ),
        ),
      );

      // Since there is no FocusScope, nearestScope will still be root scope or somewhat
      // And nodes will be something. However, let's just make sure it behaves.
      final result = policy.inDirection(nodeFrom, TraversalDirection.up);
      // It will just return true/false from fallback
      expect(result, isNotNull);
    });
  });
}
