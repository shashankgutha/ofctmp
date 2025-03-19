{
  "source": {
    "index": "testreid",
    "query": {
    "regexp": {
      "a": {
        "value": "[0-9]+"
      }
    }
  }
  },
  "dest": {
    "index": "new_testreid_v2"
  },
  "script": {
    "source": "ctx._source.a = Integer.parseInt(ctx._source.a)"
  }
}
