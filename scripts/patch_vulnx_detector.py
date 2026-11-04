#!/usr/bin/env python3
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
# VANTAGE / INFRA AI OU PROJECT NOTICE
# Project-maintained VAPT integration by Andrea Bodei and INFRA AI OU for the
# VANTAGE project under the European Commission DIGITAL programme.
# AUTHORIZED USE ONLY: governments, companies, professionals, and other entities
# may use these tools only with explicit permission to perform VAPT against each
# specific target and only within the approved scope and rules of engagement.
# This repository grants no explicit or implicit authorization to test any target.
# Andrea Bodei, INFRA AI OU, the VANTAGE project, the DIGITAL programme, and the
# European Commission disclaim responsibility for unauthorized use or misuse.
# See PROJECT_NOTICE.md; applicable licenses and upstream notices remain authoritative.

# Copyright © 2026 Andrea Bodei — www.andreabodei.com
"""Apply and validate the bounded VulnX detector HTTP hardening patch."""

from __future__ import annotations

import argparse
import ast
import io
import os
from pathlib import Path
import stat
import sys
import tempfile
import tokenize
from typing import Iterable, Sequence

HELPER_NAME = "_safe_get_text"
TARGET_GETTERS = {
    "__getlmcontent__": "lm_content",
    "__getlm2content__": "lm2_content",
    "__getcontent__": "self.url",
}
GETTER_SETUP = {
    "__getlmcontent__": ("lm_content", "self.url + '/smiley/1.gif'"),
    "__getlm2content__": ("lm2_content", "self.url + '/rss.xml'"),
    "__getcontent__": None,
}


class PatchError(RuntimeError):
    """Raised when detector.py does not have a safely patchable structure."""


def _parse(source: str, filename: str) -> ast.Module:
    try:
        return ast.parse(source, filename=filename)
    except SyntaxError as exc:
        raise PatchError(f"detector source is not valid Python: {exc}") from exc


def _same_expression(node: ast.AST, expression: str) -> bool:
    expected = ast.parse(expression, mode="eval").body
    return ast.dump(node, include_attributes=False) == ast.dump(
        expected, include_attributes=False
    )


def _is_self_attribute(node: ast.AST, attribute: str) -> bool:
    return (
        isinstance(node, ast.Attribute)
        and node.attr == attribute
        and isinstance(node.value, ast.Name)
        and node.value.id == "self"
    )


def _is_requests_get_call(node: ast.AST) -> bool:
    return (
        isinstance(node, ast.Call)
        and isinstance(node.func, ast.Attribute)
        and node.func.attr == "get"
        and isinstance(node.func.value, ast.Name)
        and node.func.value.id == "requests"
    )


def _is_helper_call(node: ast.AST | None) -> bool:
    return (
        isinstance(node, ast.Call)
        and isinstance(node.func, ast.Attribute)
        and node.func.attr == HELPER_NAME
        and isinstance(node.func.value, ast.Name)
        and node.func.value.id == "self"
    )


def _keyword_map(call: ast.Call) -> dict[str, ast.AST] | None:
    keywords: dict[str, ast.AST] = {}
    for keyword in call.keywords:
        if keyword.arg is None or keyword.arg in keywords:
            return None
        keywords[keyword.arg] = keyword.value
    return keywords


def _single_direct_return(function: ast.FunctionDef) -> ast.Return | None:
    direct_returns = [
        statement for statement in function.body if isinstance(statement, ast.Return)
    ]
    all_returns = [node for node in ast.walk(function) if isinstance(node, ast.Return)]
    if len(direct_returns) != 1 or len(all_returns) != 1:
        return None
    return direct_returns[0]


def _raw_request_return(
    return_node: ast.Return,
    expected_argument: str,
    *,
    require_timeout: bool,
) -> bool:
    value = return_node.value
    if not (
        isinstance(value, ast.Attribute)
        and value.attr == "text"
        and _is_requests_get_call(value.value)
    ):
        return False

    call = value.value
    assert isinstance(call, ast.Call)
    if len(call.args) != 1 or not _same_expression(call.args[0], expected_argument):
        return False

    keywords = _keyword_map(call)
    expected_keywords = (
        {"headers", "verify", "timeout"}
        if require_timeout
        else {
            "headers",
            "verify",
        }
    )
    if keywords is None or set(keywords) != expected_keywords:
        return False
    if not _is_self_attribute(keywords["headers"], "headers"):
        return False
    if not (
        isinstance(keywords["verify"], ast.Constant)
        and keywords["verify"].value is False
    ):
        return False
    if require_timeout and not (
        isinstance(keywords["timeout"], ast.Constant)
        and type(keywords["timeout"].value) is int
        and keywords["timeout"].value == 12
    ):
        return False
    return True


def _safe_helper_return(return_node: ast.Return, expected_argument: str) -> bool:
    call = return_node.value
    return bool(
        _is_helper_call(call)
        and isinstance(call, ast.Call)
        and len(call.args) == 1
        and not call.keywords
        and _same_expression(call.args[0], expected_argument)
    )


def _find_cms_class(tree: ast.Module) -> ast.ClassDef:
    top_level = [
        node
        for node in tree.body
        if isinstance(node, ast.ClassDef) and node.name == "CMS"
    ]
    all_cms_classes = [
        node
        for node in ast.walk(tree)
        if isinstance(node, ast.ClassDef) and node.name == "CMS"
    ]
    if len(top_level) != 1 or len(all_cms_classes) != 1:
        raise PatchError("expected exactly one top-level CMS class")
    return top_level[0]


def _target_methods(cms_class: ast.ClassDef) -> dict[str, ast.FunctionDef]:
    result: dict[str, ast.FunctionDef] = {}
    for method_name in TARGET_GETTERS:
        matches = [
            node
            for node in cms_class.body
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
            and node.name == method_name
        ]
        if len(matches) != 1 or not isinstance(matches[0], ast.FunctionDef):
            raise PatchError(f"expected exactly one CMS.{method_name} method")
        result[method_name] = matches[0]
    return result


def _helper_definitions(
    tree: ast.Module,
) -> list[ast.FunctionDef | ast.AsyncFunctionDef]:
    return [
        node
        for node in ast.walk(tree)
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
        and node.name == HELPER_NAME
    ]


def _has_simple_self_signature(function: ast.FunctionDef) -> bool:
    arguments = function.args
    positional = [*arguments.posonlyargs, *arguments.args]
    return bool(
        [argument.arg for argument in positional] == ["self"]
        and arguments.vararg is None
        and arguments.kwarg is None
        and not arguments.kwonlyargs
        and not arguments.defaults
        and not arguments.kw_defaults
        and not function.decorator_list
        and function.returns is None
    )


def _has_expected_getter_body(
    function: ast.FunctionDef, method_name: str, return_node: ast.Return
) -> bool:
    setup = GETTER_SETUP[method_name]
    if setup is None:
        return function.body == [return_node]
    if len(function.body) != 2 or function.body[1] is not return_node:
        return False
    assignment = function.body[0]
    if not (
        isinstance(assignment, ast.Assign)
        and len(assignment.targets) == 1
        and isinstance(assignment.targets[0], ast.Name)
        and assignment.targets[0].id == setup[0]
        and _same_expression(assignment.value, setup[1])
    ):
        return False
    return True


def _classify_getter(
    function: ast.FunctionDef,
    method_name: str,
    expected_argument: str,
) -> tuple[str, ast.Return | None]:
    return_node = _single_direct_return(function)
    if (
        return_node is None
        or not _has_simple_self_signature(function)
        or not _has_expected_getter_body(function, method_name, return_node)
    ):
        return "unknown", None

    request_calls = [node for node in ast.walk(function) if _is_requests_get_call(node)]
    helper_calls = [node for node in ast.walk(function) if _is_helper_call(node)]

    if (
        len(request_calls) == 1
        and not helper_calls
        and _raw_request_return(return_node, expected_argument, require_timeout=False)
    ):
        return "raw", return_node
    if (
        not request_calls
        and len(helper_calls) == 1
        and _safe_helper_return(return_node, expected_argument)
    ):
        return "safe", return_node
    return "unknown", return_node


def _exception_is_request_exception(node: ast.AST | None) -> bool:
    return bool(
        isinstance(node, ast.Attribute)
        and node.attr == "RequestException"
        and isinstance(node.value, ast.Attribute)
        and node.value.attr == "exceptions"
        and isinstance(node.value.value, ast.Name)
        and node.value.value.id == "requests"
    )


def _validate_helper(helper: ast.FunctionDef) -> None:
    arguments = helper.args
    positional = [*arguments.posonlyargs, *arguments.args]
    if (
        [argument.arg for argument in positional] != ["self", "url"]
        or arguments.vararg is not None
        or arguments.kwarg is not None
        or arguments.kwonlyargs
        or arguments.defaults
        or arguments.kw_defaults
        or helper.decorator_list
        or helper.returns is not None
    ):
        raise PatchError("VulnX safe HTTP helper has an unexpected signature")

    if len(helper.body) != 1 or not isinstance(helper.body[0], ast.Try):
        raise PatchError("VulnX safe HTTP helper has an unexpected body")
    try_node = helper.body[0]
    if try_node.orelse or try_node.finalbody or len(try_node.handlers) != 1:
        raise PatchError("VulnX safe HTTP helper has unexpected control flow")
    if len(try_node.body) != 1 or not isinstance(try_node.body[0], ast.Return):
        raise PatchError("VulnX safe HTTP helper must directly return response text")
    if not _raw_request_return(try_node.body[0], "url", require_timeout=True):
        raise PatchError(
            "VulnX safe HTTP helper must use timeout=12, headers, and verify=False"
        )

    handler = try_node.handlers[0]
    if (
        not _exception_is_request_exception(handler.type)
        or handler.name is not None
        or len(handler.body) != 1
        or not isinstance(handler.body[0], ast.Return)
        or not isinstance(handler.body[0].value, ast.Constant)
        or handler.body[0].value.value != ""
    ):
        raise PatchError(
            "VulnX safe HTTP helper must return an empty string on RequestException"
        )


def _validate_hardened(source: str, filename: str) -> ast.Module:
    tree = _parse(source, filename)
    cms_class = _find_cms_class(tree)
    helpers = _helper_definitions(tree)
    if (
        len(helpers) != 1
        or not isinstance(helpers[0], ast.FunctionDef)
        or helpers[0] not in cms_class.body
    ):
        raise PatchError("expected exactly one CMS safe HTTP helper")
    _validate_helper(helpers[0])

    methods = _target_methods(cms_class)
    for method_name, expected_argument in TARGET_GETTERS.items():
        state, _ = _classify_getter(
            methods[method_name], method_name, expected_argument
        )
        if state != "safe":
            raise PatchError(
                f"CMS.{method_name} is not exclusively routed through {HELPER_NAME}"
            )
    try:
        compile(source, filename, "exec")
    except (SyntaxError, ValueError, TypeError) as exc:
        raise PatchError(f"hardened detector did not compile: {exc}") from exc
    return tree


def _character_column(line: str, utf8_byte_column: int) -> int:
    encoded = line.encode("utf-8")
    try:
        return len(encoded[:utf8_byte_column].decode("utf-8"))
    except UnicodeDecodeError as exc:
        raise PatchError("AST column did not align with detector source") from exc


def _source_lines_and_offsets(source: str) -> tuple[list[str], list[int]]:
    lines = source.splitlines(keepends=True)
    offsets: list[int] = []
    position = 0
    for line in lines:
        offsets.append(position)
        position += len(line)
    return lines, offsets


def _node_span(
    node: ast.stmt | ast.expr,
    lines: Sequence[str],
    offsets: Sequence[int],
) -> tuple[int, int]:
    if (
        not hasattr(node, "lineno")
        or not hasattr(node, "end_lineno")
        or node.end_lineno is None
        or node.end_col_offset is None
    ):
        raise PatchError("Python AST did not provide source positions")
    start_line = node.lineno - 1
    end_line = node.end_lineno - 1
    start = offsets[start_line] + _character_column(lines[start_line], node.col_offset)
    end = offsets[end_line] + _character_column(lines[end_line], node.end_col_offset)
    return start, end


def _line_indent(
    node: ast.stmt,
    lines: Sequence[str],
    offsets: Sequence[int],
) -> str:
    start, _ = _node_span(node, lines, offsets)
    line_start = offsets[node.lineno - 1]
    indent = "".join(lines)[line_start:start]
    if indent.strip():
        raise PatchError("unexpected non-whitespace before a detector statement")
    return indent


def _newline_style(source: str) -> str:
    crlf_count = source.count("\r\n")
    lf_count = source.count("\n") - crlf_count
    return "\r\n" if crlf_count > lf_count else "\n"


def _helper_source(
    method: ast.FunctionDef,
    lines: Sequence[str],
    offsets: Sequence[int],
    newline: str,
) -> str:
    if not method.body:
        raise PatchError("cannot infer indentation from an empty getter")
    method_indent = _line_indent(method, lines, offsets)
    body_indent = _line_indent(method.body[0], lines, offsets)
    if not body_indent.startswith(method_indent) or len(body_indent) <= len(
        method_indent
    ):
        raise PatchError("cannot infer VulnX method indentation")
    indentation_unit = body_indent[len(method_indent) :]
    nested_indent = body_indent + indentation_unit
    return (
        f"{method_indent}def {HELPER_NAME}(self, url):{newline}"
        f"{body_indent}try:{newline}"
        f"{nested_indent}return requests.get("
        f"url, headers=self.headers, verify=False, timeout=12).text{newline}"
        f"{body_indent}except requests.exceptions.RequestException:{newline}"
        f'{nested_indent}return ""{newline}'
        f"{newline}"
    )


def _apply_edits(source: str, edits: Iterable[tuple[int, int, str]]) -> str:
    ordered = sorted(edits, key=lambda edit: (edit[0], edit[1]), reverse=True)
    previous_start = len(source) + 1
    result = source
    for start, end, replacement in ordered:
        if start < 0 or end < start or end > len(source) or end > previous_start:
            raise PatchError("overlapping or invalid detector source edits")
        result = result[:start] + replacement + result[end:]
        previous_start = start
    return result


def _transform_pristine(
    source: str,
    filename: str,
    methods: dict[str, ast.FunctionDef],
    returns: dict[str, ast.Return],
) -> str:
    lines, offsets = _source_lines_and_offsets(source)
    if not lines:
        raise PatchError("detector source is empty")

    edits: list[tuple[int, int, str]] = []
    for method_name, expected_argument in TARGET_GETTERS.items():
        start, end = _node_span(returns[method_name], lines, offsets)
        edits.append(
            (
                start,
                end,
                f"return self.{HELPER_NAME}({expected_argument})",
            )
        )

    first_getter = min(methods.values(), key=lambda method: method.lineno)
    insertion = offsets[first_getter.lineno - 1]
    edits.append(
        (
            insertion,
            insertion,
            _helper_source(first_getter, lines, offsets, _newline_style(source)),
        )
    )
    transformed = _apply_edits(source, edits)
    _validate_hardened(transformed, filename)
    return transformed


def _decode_source(data: bytes) -> tuple[str, str]:
    try:
        encoding, _ = tokenize.detect_encoding(io.BytesIO(data).readline)
        return data.decode(encoding), encoding
    except (SyntaxError, UnicodeDecodeError, LookupError) as exc:
        raise PatchError(f"unable to decode detector source: {exc}") from exc


def _atomic_replace(path: Path, data: bytes, mode: int) -> None:
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent)
    )
    temporary_path = Path(temporary_name)
    descriptor_open = True
    try:
        with os.fdopen(descriptor, "wb") as handle:
            descriptor_open = False
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary_path, mode)
        os.replace(temporary_path, path)
    except BaseException:
        if descriptor_open:
            os.close(descriptor)
        try:
            temporary_path.unlink()
        except FileNotFoundError:
            pass
        raise


def patch_detector(detector_path: os.PathLike[str] | str) -> bool:
    """Harden detector.py atomically.

    Return ``True`` when a pristine detector was changed and ``False`` when it
    was already fully hardened. Any unrecognized or partial state raises
    :class:`PatchError` before the original path is replaced.
    """

    path = Path(detector_path)
    if path.is_symlink():
        raise PatchError("refusing to replace a detector.py symbolic link")
    try:
        file_stat = path.stat()
    except OSError as exc:
        raise PatchError(f"unable to stat detector source: {exc}") from exc
    if not stat.S_ISREG(file_stat.st_mode):
        raise PatchError("detector path is not a regular file")

    try:
        original_data = path.read_bytes()
    except OSError as exc:
        raise PatchError(f"unable to read detector source: {exc}") from exc
    source, encoding = _decode_source(original_data)
    tree = _parse(source, str(path))
    cms_class = _find_cms_class(tree)
    methods = _target_methods(cms_class)
    helpers = _helper_definitions(tree)

    states: dict[str, str] = {}
    returns: dict[str, ast.Return] = {}
    for method_name, expected_argument in TARGET_GETTERS.items():
        state, return_node = _classify_getter(
            methods[method_name], method_name, expected_argument
        )
        states[method_name] = state
        if return_node is not None:
            returns[method_name] = return_node

    state_values = set(states.values())
    if state_values == {"safe"} and len(helpers) == 1:
        _validate_hardened(source, str(path))
        return False
    if state_values == {"raw"} and not helpers and len(returns) == len(TARGET_GETTERS):
        transformed = _transform_pristine(source, str(path), methods, returns)
    else:
        detail = ", ".join(f"{name}={states[name]}" for name in TARGET_GETTERS)
        raise PatchError(
            "detector is neither fully pristine nor fully hardened "
            f"({detail}; helper_count={len(helpers)})"
        )

    try:
        transformed_data = transformed.encode(encoding)
    except UnicodeEncodeError as exc:
        raise PatchError(f"unable to encode hardened detector: {exc}") from exc
    if transformed_data == original_data:
        raise PatchError("pristine detector transformation made no changes")

    _atomic_replace(path, transformed_data, stat.S_IMODE(file_stat.st_mode))
    return True


def _argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Apply and validate VulnX detector HTTP hardening."
    )
    parser.add_argument("detector", help="path to VulnX modules/detector.py")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _argument_parser().parse_args(argv)
    try:
        changed = patch_detector(args.detector)
    except (PatchError, OSError) as exc:
        print(f"VulnX detector patch failed: {exc}", file=sys.stderr)
        return 1
    status = "patched" if changed else "already hardened"
    print(f"VulnX detector {status}: {args.detector}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
# Copyrights to Andrea Bodei 2026-2036 www.andreabodei.com
