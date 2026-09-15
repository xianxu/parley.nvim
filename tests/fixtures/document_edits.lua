-- Independent readable cases used by grammar and incremental edit-sequence tests.
return {
    { name='ordinary fence leaves questions structural', lines={
        '💬: one','🤖: answer','```lua','📎: quoted','💬: two','```','🤖: second'},
        exchange_rows={1,5}, answer_rows={2,7} },
    { name='complete and empty tools', lines={
        '💬: one','🤖: answer','🔧: call','```json','{}','```',
        '📎: result','```','```','plain','💬: two','🤖: next'},
        exchange_rows={1,11},answer_rows={2,12} },
    { name='reasoning explicit and legacy', lines={
        '💬: one','🤖: answer','🧠: think','','continued','🧠:[END]',
        '📝: summary','plain','🧠: legacy','','plain'},
        exchange_rows={1},answer_rows={2} },
    { name='annotations and tagged question', lines={
        '💬: one','🤖: answer','🔒: note','🌿: other.md: other','@@next@@',
        '💬: two','🤖: next'},exchange_rows={1,6},answer_rows={2,7} },
    { name='tool interrupted by question',lines={
        '💬: one','🤖: answer','📎: incomplete','```','partial','💬: two','🤖: next'},
        exchange_rows={1,6},answer_rows={2,7} },
}
