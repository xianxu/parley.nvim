---
topic: adversarial fence and marker shapes
file: fold_adversarial.md
---

💬: read the transcript file and tell me what is in it

🤖: [A]

🧠: the file is itself a chat transcript, so its contents will look structural

🔧: read_file id=a1
```json
{"path":"workshop/parley/example.md"}
```

📎: read_file id=a1
````
    1  💬: a question that lives inside the file being read
    2  🤖: and the answer that follows it
    3  📎: read_file id=nested
    4  ```
    5  this nested block uses a shorter fence
    6  ```
    7  📝: even a summary marker in here is content
````

📝: read the transcript; its contents only look structural

The file contains a chat transcript, which is why its body is full of
markers that are not turns.

💬: now grep for the marker itself

🤖: [A]

🔧: grep id=a2
```json
{"pattern":"💬:"}
```

📎: grep id=a2
```
example.md:1: 💬: a question that lives inside the file being read
```

📝: grepped for the question marker

One match.
