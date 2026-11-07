#!/usr/bin/env python3
"""Map a pinned Python public behavior inventory to the deliberate Perl surface."""
import argparse
import ast
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
PIN=json.loads((ROOT/'scripts/conformance-reference.json').read_text())
REFERENCE=ROOT/'.cache/reference-python/src/libtmux'
MAPPED={
    'new_session':'new_session','new_window':'new_window','split_window':'split_pane','split':'split_pane',
    'rename_session':'rename_session','rename_window':'rename_window','kill_session':'kill_session',
    'kill_window':'kill_window','kill_pane':'kill_pane','kill_server':'kill_server','link_window':'link_window',
    'unlink_window':'unlink_window','move_window':'move_window','select_window':'select_window',
    'select_pane':'select_pane','select_layout':'select_layout','resize_pane':'resize_pane',
    'send_keys':'send_keys','capture_pane':'capture_pane','set_title':'set_title','cmd':'cmd',
    'set_option':'set_option','show_option':'get_option','unset_option':'unset_option',
    'set_hook':'set_hook','show_hooks':'show_hooks','set_environment':'set_environment',
    'show_environment':'get_environment','unset_environment':'unset_environment',
    'detach':'detach_client','attach_session':'attach_argv',
}
ADAPTED={
    '__init__':('LibTmux::Server::new / captured entity readers','Construct only connection settings; entity handles come from explicit snapshots and never own transport.'),
    'sessions':('LibTmux::Snapshot::sessions','Explicit acquisition replaces implicit live collection access.'),
    'windows':('LibTmux::Snapshot::windows / Session::window_links','Physical identity is unique; session associations remain WindowLink records.'),
    'panes':('LibTmux::Snapshot::panes / Window::panes','Captured physical membership is local and repeatable.'),
    'clients':('LibTmux::Server::clients','Explicit acquisition returns captured client data.'),
    'session':('LibTmux::Window::links / WindowLink::session','A physical window or pane has no arbitrary singular session context.'),
    'window':('LibTmux::Pane::window','Resolve the retained physical window without I/O.'),
    'refresh':('LibTmux::Server::snapshot','New observations do not mutate retained snapshots.'),
    'get_by_id':('LibTmux::Snapshot::*_by_id','Local identity lookup returns one handle or undef, scoped to the captured server generation.'),
    'get':('LibTmux::Selection::one / one_or_undef','Fixed cardinality returns; ambiguity is a typed failure.'),
    'filter':('LibTmux::Selection::where / grep','Validated criteria data and native callbacks replace QueryList lookup spelling.'),
    'find_where':('LibTmux::Selection::first','Optional criteria and explicit absence; no context-sensitive return.'),
    'where':('LibTmux::Selection::where','Eager, nonmutating captured selection with an explicit schema.'),
    'active_window':('LibTmux::Session::window_links','Filter the session link active flag, then resolve its physical window.'),
    'active_pane':('LibTmux::Window::active_pane','Local captured active-pane relation; unknown completeness cannot prove absence.'),
    'attached_window':('LibTmux::WindowLink::active','Session-relative active context is represented explicitly.'),
    'attached_pane':('LibTmux::Window::active_pane','Physical pane active state differs from session-relative link state.'),
    'show_options':('LibTmux::Server::get_option / cmd','Named scoped/inherited reads are wrapped; bulk native listings remain explicit command results.'),
}
for row in json.loads((ROOT/'docs/behavior-inventory.json').read_text())['methods']:
    MAPPED.setdefault(row['key'],row['key'])

def contextual(owner,name):
    kind={'Pane':'pane','Window':'window','Session':'session','Client':'client'}.get(owner)
    if name in ('id','name','width','height','title','index') and kind:
        if kind=='window' and name=='index':return ('LibTmux::WindowLink::index','Window index is session-relative link context, not a physical-window field.')
        fields=json.loads((ROOT/'packages/core/lib/LibTmux/schema.json').read_text())['entities'][kind]['fields']
        if name in fields:return (f'LibTmux::{owner}::{name}','Schema-backed captured reader; no implicit I/O or live refresh.')
    if name=='kill' and owner in ('Pane','Window','Session','Server'):return ('LibTmux::Server::kill_'+(kind or 'server'),'Explicit mutation on Server; captured entities do not own transport or destruct borrowed resources.')
    if name=='select' and owner in ('Pane','Window'):
        return ('LibTmux::Server::select_'+kind,'Window selection requires a WindowLink; pane selection uses a physical pane ID.')
    if name=='resize' and owner=='Pane':return ('LibTmux::Server::resize_pane','Explicit dimensions and stable pane targeting.')
    if name in ('set_width','set_height') and owner=='Pane':return ('LibTmux::Server::resize_pane','Set the explicit width or height option without implicit refresh.')
    if name=='enter' and owner=='Pane':return ('LibTmux::Server::send_keys','Pass the named Enter key to the explicit pane target.')
    if name=='new_pane':return ('LibTmux::Server::split_pane','Choose the pane explicitly; a Window caller can select its captured active_pane.')
    if name=='attach' and owner=='Session':return ('LibTmux::Server::attach_argv','Caller owns the interactive terminal/client lifetime.')
    if name in ('link','unlink') and owner=='Window':return ('LibTmux::Server::'+name+'_window','Link creation uses physical identity; unlinking requires explicit WindowLink context.')
    if name=='linked_sessions':return ('LibTmux::Window::links','Resolve each WindowLink session locally; preserve repeated associations.')
    if name=='attached_session' and owner=='Client':return ('LibTmux::Client::session','Captured nullable session relation with explicit availability.')
    if name.startswith('from_') and name.endswith(('_id','_name')) and kind:
        return ('LibTmux::Snapshot / LibTmux::Selection::one','Acquire explicitly, then resolve the stable ID or validated name; do not select arbitrary context.')
    if name in ('is_alive','raise_if_dead','has_session','attached_sessions'):
        return ('LibTmux::Server::snapshot / LibTmux::Selection','Explicit acquisition propagates operational failures; local predicates test captured membership or attachment count.')
    if name in ('list_sessions','list_windows','list_panes','list_clients'):
        return ('LibTmux::Server::listings','Raw contextual rows retain ordering/multiplicity; normalized Snapshot collections are a separate API.')
    if name.startswith('search_'):return ('LibTmux::Server::query_panes / LibTmux::Selection','Portable eager criteria and explicit native filters replace Python search spelling; regex is a local callback capability, not implicit native translation.')
    if name=='display_message':return ('LibTmux::Server::cmd','Use explicit display-message argv, -p, and the stable target ID. Native formats remain an expert interface.')
    if name=='children':return ('LibTmux::Snapshot / Session::window_links / Window::panes','Use typed captured graph relations without hidden acquisition.')
    if name=='items' and owner=='QueryList':return ('Native Perl arrays and map','Use indexing or explicit ID projection; duplicate occurrence semantics stay visible.')
    if name=='getenv':return ('LibTmux::Server::get_environment','Explicit named global/session read; unset values remain failures.')
    if name in ('set_window_option','show_window_option'):return ('LibTmux::Server::set_option / get_option','Pass scope=window and an explicit physical-window ID; inherited reads are explicit.')
    if name=='show_window_options':return ('LibTmux::Server::cmd','Bulk show-options -w output remains a native command result.')
    return None

rows=[]
for file in ('server.py','session.py','window.py','pane.py','client.py','common.py','_internal/query_list.py'):
    path=REFERENCE/file
    if not path.exists():continue
    tree=ast.parse(path.read_text())
    for owner in (node for node in ast.walk(tree) if isinstance(node,ast.ClassDef)):
        for method in owner.body:
            if not isinstance(method,(ast.FunctionDef,ast.AsyncFunctionDef)) or method.name.startswith('_') and method.name!='__init__':continue
            name=method.name
            row={'python':owner.name+'.'+name,'file':'src/libtmux/'+file,'line':method.lineno,'source_revision':PIN['revision']}
            doc=ast.get_docstring(method)
            if doc:row['behavior']=doc.split('\n',1)[0]
            selected=contextual(owner.name,name)
            if selected:
                target,reason=selected;row.update(disposition='native-adaptation',perl=target,reason=reason)
            elif name in ADAPTED:
                target,reason=ADAPTED[name];row.update(disposition='native-adaptation',perl=target,reason=reason)
            elif name in MAPPED:
                target=MAPPED[name];row.update(disposition='mapped-operation',perl='LibTmux::Server::'+target,reason='Explicit Server operation with stable ID or captured handle; native argument/result contracts are authoritative.')
            else:
                row.update(disposition='excluded-wrapper',perl='LibTmux::Server::cmd',reason='No dedicated wrapper in the selected initial surface. Native tmux commands remain explicit argument vectors with caller-selected targeting and ownership; no Python wrapper parity is claimed.')
            rows.append(row)
result={'schema':1,'source':{'repository':PIN['repository'],'revision':PIN['revision']},'scope':'Declared public methods/properties of the pinned core entity, common, and QueryList classes; tmux fields remain governed by the independent Perl catalog. Excluded wrappers are deliberate and do not transfer Python error suppression or implicit I/O.','rows':sorted(rows,key=lambda row:(row['file'],row['line']))}
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check',action='store_true');args=parser.parse_args()
output=ROOT/'docs/python-behavior-inventory.json';expected=json.dumps(result,indent=2)+'\n'
if args.check:
    if not output.exists() or output.read_text()!=expected:raise SystemExit('Python behavior inventory drift; regenerate after reviewing mappings')
else:output.write_text(expected)
print(f'{len(rows)} pinned Python behavior rows inventoried with explicit dispositions')
