"""Conservative condition normalization for the Roles v2.1.x decoder."""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from typing import Final, NamedTuple, override

type Condition = tuple[int, int, int, str]
PURE_OPERATORS: Final = frozenset((0, 1, 2, 3, 5, 6, 7, 8, 15, 16, 17, 18, 19, 20, 21))


@dataclass(frozen=True, slots=True)
class ReplayError(RuntimeError):
    reason: str

    @override
    def __str__(self) -> str:
        return self.reason


class TypeTree(NamedTuple):
    parameter_type: int
    children: tuple[TypeTree, ...]


class CanonicalNode(NamedTuple):
    parameter_type: int
    operator: int
    comparison: str
    children: tuple[CanonicalNode, ...]


def canonical(
    conds: Sequence[Condition] | None, prune_trailing_pass: bool = True
) -> CanonicalNode | None:
    """Normalize only pure, shape-identical Or permutations and root static tails."""
    if conds is None:
        return None
    if not conds or conds[0][0] != 0:
        raise ReplayError("condition tree requires a root")
    children: list[list[int]] = [[] for _ in conds]
    for index in range(1, len(conds)):
        parent = conds[index][0]
        if not 0 <= parent < index:
            raise ReplayError("condition parent must precede its child")
        children[parent].append(index)

    def shape(index: int) -> tuple:
        # Operator/type shape, compValues excluded. Equal shapes imply equal decoder type trees
        # and equal read positions, so neither decoding nor revert order depends on Or order.
        _, parameter_type, operator, _ = conds[index]
        return (parameter_type, operator, tuple(shape(child) for child in children[index]))

    def pure(index: int) -> bool:
        return conds[index][2] in PURE_OPERATORS and all(
            pure(child) for child in children[index]
        )

    def serialize(index: int) -> CanonicalNode:
        _, parameter_type, operator, comparison = conds[index]
        descendants = children[index]
        nodes = [serialize(child) for child in descendants]
        # Only pure Or alternatives with identical operator/type shape may be reordered.
        if operator == 2 and descendants and pure(index):
            template = shape(descendants[0])
            if all(shape(child) == template for child in descendants):
                nodes.sort()
        # Nested layouts can shift later siblings; only the root has no such sibling.
        if index == 0 and parameter_type == 5 and operator == 5 and prune_trailing_pass:
            while (
                nodes
                and nodes[-1].parameter_type == 1
                and nodes[-1].operator == 0
                and not nodes[-1].children
            ):
                _ = nodes.pop()
        return CanonicalNode(parameter_type, operator, comparison, tuple(nodes))

    return serialize(0)
