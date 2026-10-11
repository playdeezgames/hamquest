"""Loader for the original HamQuest XML config, mirroring the C# semantics.

Mirrors HamQuestEngine/Item/Descriptor.cs PropertyValuePair.LoadPropertyValuesFromXmlNode:
  * `template="a,b,c"` loads each file's root element recursively and concatenates properties;
    identifiers concatenate (template identifiers first, then the node's own).
  * later properties replace earlier ones of the same name (Descriptor.SetProperty).
  * untyped values parse as int, then float, then bool, else string (invariant culture assumed).
  * `type="X"` values are structured and kept as ('X', element) for the schema layer.
"""
import os
import re
import xml.etree.ElementTree as ET

INT_RE = re.compile(r'^\s*[+-]?\d+\s*$')
FLOAT_RE = re.compile(r'^\s*[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?\s*$')


def parse_scalar(text):
    t = text if text is not None else ''
    if INT_RE.match(t):
        return int(t)
    if FLOAT_RE.match(t):
        return float(t)
    s = t.strip()
    if s.lower() == 'true':
        return True
    if s.lower() == 'false':
        return False
    return t


class Typed:
    """A property whose XML element carried type="Name"."""
    def __init__(self, type_name, element, source):
        self.type_name = type_name
        self.element = element
        self.source = source

    def __repr__(self):
        return 'Typed(%s)' % self.type_name


def load_root(path):
    # utf-8-sig strips the BOM
    with open(path, encoding='utf-8-sig') as f:
        return ET.fromstring(f.read())


def load_properties(node, base_dir, source, trace=None):
    """Returns (ordered list of (name, value, source_file)), identifier)."""
    props = []
    identifier = ''
    tpl = node.get('template')
    if tpl:
        for fname in tpl.split(','):
            path = os.path.join(base_dir, fname)
            root = load_root(path)
            if root.tag != node.tag:
                raise ValueError('%s: template root <%s> != <%s>' % (path, root.tag, node.tag))
            sub, ident = load_properties(root, base_dir, path, trace)
            identifier += ident
            props.extend(sub)
    for el in node:
        name = el.tag
        if name == 'identifier':
            identifier += el.text or ''
        elif el.get('type') is not None:
            props.append((name, Typed(el.get('type'), el, source), source))
        else:
            props.append((name, parse_scalar(el.text), source))
    return props, identifier


def resolve(props):
    """Apply 'later replaces earlier' keeping first-seen order."""
    out = {}
    for name, value, src in props:
        out[name] = (value, src)
    return out


def load_index(path, base_dir, item_tag):
    root = load_root(path)
    result = []
    for node in root.findall(item_tag):
        props, ident = load_properties(node, base_dir, path)
        result.append({
            'identifier': ident,
            'node_type': node.get('type'),
            'props': resolve(props),
            'raw': props,
            'template': node.get('template'),
        })
    return result
