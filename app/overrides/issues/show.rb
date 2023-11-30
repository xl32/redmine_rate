module Issues::Show
  Deface::Override.new virtual_path: 'issues/_edit',
                       name:         'add-timelog-issue-hook',
                       insert_after: 'div.splitcontent',
                       original:     '69fd1ee11dddc1b4fd8bf5d963bd6f342b273b6f',
                       partial:      'issues/timelog_hook'
end
