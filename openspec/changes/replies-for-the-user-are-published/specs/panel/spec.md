## ADDED Requirements

### Requirement: The key replies page states what it is and who publishes into it

Page 5 of the console SHALL carry one line describing the page itself: that it holds the replies the PM wrote for
the user — the answers, conclusions, rulings, reports and decision requests the PM sends to the conversation — and
that the PM is the one who publishes them. The line SHALL come from the zh/en string tables like every other static
label, SHALL be sanitized and truncated to the pane width, and SHALL stay readable in all four width tiers and in
both languages; it SHALL be drawn whenever the page's list renders, including an empty store and a degraded or
unavailable read. The line is a statement, not a control: it SHALL carry no mouse target and no action, and the
page's read-only contract is unchanged — the console still publishes nothing, edits nothing and offers no marking
action. No part of the console reads chat, sessions or history, so the line MUST NOT claim that a reply is marked
by itself; it says where user-facing replies land, and publishing stays the PM's act.

#### Scenario: The page names itself in both languages
- **WHEN** page 5 renders a fixture store in zh and in en at 160, 120, 99 and 59 columns
- **THEN** the description line is present in the pane in both languages and no rendered line exceeds the pane width
- **AND** the line carries no mouse target: clicking its row changes neither the page, the focus nor the store

#### Scenario: Nothing marks a question for the user
- **WHEN** page 5 is rendered with typed text in the compose line and the recorded reader calls of that frame are inspected
- **THEN** the description line carries the same text as in a quiet fixture, and the only readers recorded are the bounded key-reply block reads
- **AND** no chat, session or history reader is consulted, so the console has no way to learn what the user just asked and cannot claim to have marked the reply
