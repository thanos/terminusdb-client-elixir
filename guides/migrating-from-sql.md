# Migrating from SQL to TerminusDB

This guide shows how to model relational data in TerminusDB using
`terminusdb_ex`. We take a typical SQL schema and translate it step by step,
highlighting the differences and what you gain.

---

## The SQL schema

Consider a simple blog application with users, posts, and comments:

```sql
CREATE TABLE users (
    id    SERIAL PRIMARY KEY,
    name  VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL
);

CREATE TABLE posts (
    id       SERIAL PRIMARY KEY,
    title    VARCHAR(255) NOT NULL,
    body     TEXT,
    author_id INTEGER NOT NULL REFERENCES users(id),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE comments (
    id       SERIAL PRIMARY KEY,
    body     TEXT NOT NULL,
    post_id  INTEGER NOT NULL REFERENCES posts(id),
    author_id INTEGER NOT NULL REFERENCES users(id),
    created_at TIMESTAMP DEFAULT NOW()
);
```

### SQL queries you would write

```sql
-- All posts by Alice
SELECT p.* FROM posts p
JOIN users u ON p.author_id = u.id
WHERE u.name = 'Alice';

-- All comments on Alice's posts
SELECT c.* FROM comments c
JOIN posts p ON c.post_id = p.id
JOIN users u ON p.author_id = u.id
WHERE u.name = 'Alice';

-- Count comments per post
SELECT p.title, COUNT(c.id) AS comment_count
FROM posts p
LEFT JOIN comments c ON c.post_id = p.id
GROUP BY p.id, p.title;
```

---

## Step 1: Create a database

```elixir
config = TerminusDB.Config.new(endpoint: "http://localhost:6363")

{:ok, _} =
  TerminusDB.Database.create(config, "blog",
    label: "Blog",
    comment: "A blog migrated from SQL",
    schema: true
  )

config = TerminusDB.Config.with_database(config, "blog")
```

---

## Step 2: Define the schema

In SQL, tables define columns with types and foreign keys. In TerminusDB,
**classes** define properties with types and references to other classes.

Key differences:

| SQL | TerminusDB |
| --- | --- |
| `SERIAL PRIMARY KEY` | `@key` strategy (e.g. `Random`, `Lexical`, `Hash`) auto-generates `@id` |
| `VARCHAR(255)` | `"xsd:string"` |
| `TEXT` | `"xsd:string"` |
| `INTEGER` | `"xsd:integer"` |
| `TIMESTAMP` | `"xsd:dateTime"` |
| `FOREIGN KEY` | A property typed as the referenced class name |
| `JOIN` | Not needed; references are followed automatically (graph traversal) |

### Insert the schema documents

```elixir
# User class (maps to the users table)
{:ok, _} =
  TerminusDB.Document.insert(config,
    %{
      "@type" => "Class",
      "@id" => "User",
      "@key" => %{"@type" => "Lexical", "@fields" => ["email"]},
      "name" => "xsd:string",
      "email" => "xsd:string"
    },
    author: "admin",
    message: "Add User schema",
    graph_type: :schema
  )

# Post class (maps to the posts table)
# author_id foreign key becomes a reference: "User"
{:ok, _} =
  TerminusDB.Document.insert(config,
    %{
      "@type" => "Class",
      "@id" => "Post",
      "@key" => %{"@type" => "Random"},
      "title" => "xsd:string",
      "body" => "xsd:string",
      "author" => "User",
      "created_at" => "xsd:dateTime"
    },
    author: "admin",
    message: "Add Post schema",
    graph_type: :schema
  )

# Comment class (maps to the comments table)
# post_id and author_id foreign keys become references
{:ok, _} =
  TerminusDB.Document.insert(config,
    %{
      "@type" => "Class",
      "@id" => "Comment",
      "@key" => %{"@type" => "Random"},
      "body" => "xsd:string",
      "post" => "Post",
      "author" => "User",
      "created_at" => "xsd:dateTime"
    },
    author: "admin",
    message: "Add Comment schema",
    graph_type: :schema
  )
```

### Verify the schema

```elixir
{:ok, frame} = TerminusDB.Schema.frame(config, "Post")
# => %{
#   "@type" => "Class",
#   "title" => "xsd:string",
#   "body" => "xsd:string",
#   "author" => "User",
#   "created_at" => "xsd:dateTime"
# }
```

---

## Step 3: Insert data

In SQL you `INSERT` rows. In TerminusDB you insert documents.

### SQL `INSERT` vs TerminusDB document insert

```sql
INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com');
INSERT INTO posts (title, body, author_id) VALUES ('First Post', 'Hello', 1);
INSERT INTO comments (body, post_id, author_id) VALUES ('Nice!', 1, 2);
```

```elixir
# Insert users
{:ok, _} =
  TerminusDB.Document.insert(config,
    %{"@type" => "User", "name" => "Alice", "email" => "alice@example.com"},
    author: "admin", message: "Add Alice"
  )

{:ok, _} =
  TerminusDB.Document.insert(config,
    %{"@type" => "User", "name" => "Bob", "email" => "bob@example.com"},
    author: "admin", message: "Add Bob"
  )

# Insert a post (reference the author by @id, not by numeric FK)
{:ok, _} =
  TerminusDB.Document.insert(config,
    %{
      "@type" => "Post",
      "title" => "First Post",
      "body" => "Hello world",
      "author" => "User/alice@example.com",
      "created_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    },
    author: "admin", message: "Add first post"
  )

# Insert a comment (reference both post and author by @id)
{:ok, _} =
  TerminusDB.Document.insert(config,
    %{
      "@type" => "Comment",
      "body" => "Nice!",
      "post" => "Post/<auto-generated-id>",
      "author" => "User/bob@example.com",
      "created_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    },
    author: "admin", message: "Add comment"
  )
```

The key difference: **foreign keys become document references**. You reference
another document by its `@id` (e.g. `"User/alice@example.com"`), not by a
numeric ID. TerminusDB follows these references automatically during retrieval,
so there is no need for JOINs.

---

## Step 4: Query data

### All posts by Alice

**SQL (with JOIN):**

```sql
SELECT p.* FROM posts p
JOIN users u ON p.author_id = u.id
WHERE u.name = 'Alice';
```

**TerminusDB (no JOIN, template query):**

```elixir
{:ok, posts} =
  TerminusDB.Document.query(config, %{
    "@type" => "Post",
    "author" => "User/alice@example.com"
  })
```

Or, if you only know the name and not the `@id`, first look up the user, then
query their posts:

```elixir
{:ok, users} = TerminusDB.Document.query(config, %{"@type" => "User", "name" => "Alice"})
alice_id = hd(users)["@id"]

{:ok, posts} = TerminusDB.Document.query(config, %{"@type" => "Post", "author" => alice_id})
```

### All comments on Alice's posts

**SQL (two JOINs):**

```sql
SELECT c.* FROM comments c
JOIN posts p ON c.post_id = p.id
JOIN users u ON p.author_id = u.id
WHERE u.name = 'Alice';
```

**TerminusDB (follow references, no JOINs):**

```elixir
# Get Alice's posts, then get comments for each post
{:ok, posts} = TerminusDB.Document.query(config, %{"@type" => "Post", "author" => alice_id})

comments =
  for post <- posts,
      {:ok, cs} <- [TerminusDB.Document.query(config, %{"@type" => "Comment", "post" => post["@id"]})],
      c <- cs do
    c
  end
```

With `unfold: true` (the default), TerminusDB follows references automatically,
so you can retrieve a post and its author in one call:

```elixir
{:ok, posts} = TerminusDB.Document.get(config, type: "Post", as_list: true, unfold: true)
hd(posts)["author"]["name"]  # => "Alice"
```

---

## Step 5: Update and delete

### SQL

```sql
UPDATE posts SET title = 'Renamed' WHERE id = 1;
DELETE FROM comments WHERE id = 5;
```

### TerminusDB

```elixir
# Replace (update) a document
{:ok, post} = TerminusDB.Document.get(config, id: "Post/abc123")
{:ok, _} =
  TerminusDB.Document.replace(config,
    Map.put(post, "title", "Renamed"),
    author: "admin", message: "Rename post"
  )

# Delete a document
{:ok, _} = TerminusDB.Document.delete(config, id: "Comment/xyz789", author: "admin", message: "Remove comment")
```

---

## Key takeaways

| SQL concept | TerminusDB equivalent |
| --- | --- |
| Table | Class (schema document) |
| Row | Document (instance document) |
| Column | Property in the class definition |
| Primary key | `@key` strategy generating `@id` |
| Foreign key | Property typed as the referenced class name |
| `INSERT` | `Document.insert/3` |
| `SELECT ... WHERE` | `Document.query/3` (template matching) |
| `JOIN` | Not needed; references are followed automatically |
| `UPDATE` | `Document.replace/3` |
| `DELETE` | `Document.delete/2` |
| `CREATE TABLE` | Insert a Class document in the `:schema` graph |
| Transaction | Every write is an atomic commit with author + message |
| Migration | Insert/update Class documents in the `:schema` graph |

### What you gain by migrating

- **No JOINs**: references are followed automatically by the graph engine.
- **Version history**: every change is an immutable commit. Time-travel to any
  past state, diff two points in time, branch the entire database.
- **Schema validation**: the schema is enforced on every write, not optional.
- **Flexible nesting**: subdocuments allow deeply nested JSON without separate
  tables.
- **Audit trail**: every commit records author, timestamp, and message.
