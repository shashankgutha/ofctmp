POST _reindex
{
  "source": {
    "index": "old_index"
  },
  "dest": {
    "index": "new_index"
  },
  "script": {
    "source": """
      // Try to convert query_length to integer
      try {
        // Check if string contains only digits
        if (ctx._source.query_length != null && ctx._source.query_length.matches("^\\d+$")) {
          ctx._source.query_length = Integer.parseInt(ctx._source.query_length);
          return;
        } else {
          // Skip this document if not a valid integer
          ctx.op = "noop";
        }
      } catch (Exception e) {
        // Skip this document if conversion fails
        ctx.op = "noop";
      }
    """
  }
}
