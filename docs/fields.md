# Entity fields

Generated from the packaged field catalog. Missing fields throw; known null is explicit.

| Entity | Field | Wire | Type | Nullable | tmux source / minimum |
| --- | --- | --- | --- | --- | --- |
| client | height | height | integer | no | client_height / 3.3a |
| client | id | id | string | no | client_name / 3.3a |
| client | name | name | string | no | client_name / 3.3a |
| client | pid | pid | integer | no | client_pid / 3.3a |
| client | session | session | relation | yes | captured graph |
| client | tty | tty | bytes | no | client_tty / 3.3a |
| client | width | width | integer | no | client_width / 3.3a |
| pane | active | active | boolean | no | pane_active / 3.3a |
| pane | current_command | currentCommand | string | no | pane_current_command / 3.3a |
| pane | current_path | currentPath | bytes | no | pane_current_path / 3.3a |
| pane | cursor_shape | cursorShape | string | no | cursor_shape / 3.6 |
| pane | dead | dead | boolean | no | pane_dead / 3.3a |
| pane | exit_status | exitStatus | integer | yes | pane_dead_status / 3.3a |
| pane | height | height | integer | no | pane_height / 3.3a |
| pane | id | id | string | no | pane_id / 3.3a |
| pane | index | index | integer | no | pane_index / 3.3a |
| pane | pid | pid | integer | no | pane_pid / 3.3a |
| pane | title | title | string | no | pane_title / 3.3a |
| pane | width | width | integer | no | pane_width / 3.3a |
| pane | window | window | relation | no | captured graph |
| session | attached | attached | integer | no | session_attached / 3.3a |
| session | created | created | integer | no | session_created / 3.3a |
| session | id | id | string | no | session_id / 3.3a |
| session | name | name | string | no | session_name / 3.3a |
| session | path | path | bytes | no | session_path / 3.3a |
| session | window_links | windowLinks | relation | no | captured graph |
| window | active_pane | activePane | relation | yes | captured graph |
| window | height | height | integer | no | window_height / 3.3a |
| window | id | id | string | no | window_id / 3.3a |
| window | layout | layout | string | no | window_layout / 3.3a |
| window | links | links | relation | no | captured graph |
| window | name | name | string | no | window_name / 3.3a |
| window | panes | panes | relation | no | captured graph |
| window | width | width | integer | no | window_width / 3.3a |
| window_link | active | active | boolean | no | window_active / 3.3a |
| window_link | id | id | string | no | captured graph |
| window_link | index | index | integer | no | window_index / 3.3a |
| window_link | session | session | relation | no | captured graph |
| window_link | window | window | relation | no | captured graph |
