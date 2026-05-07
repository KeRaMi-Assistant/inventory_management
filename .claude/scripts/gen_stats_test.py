import base64, os

# Full content of statistics_service_test.dart encoded as base64
# to avoid shell quoting issues
b64 = (
    "aW1wb3J0ICdwYWNrYWdlOmZsdXR0ZXJfdGVzdC9mbHV0dGVyX3Rlc3QuZGFydCc7"
    "CmltcG9ydCAncGFja2FnZTppbnZlbnRvcnlfbWFuYWdlbWVudC9tb2RlbHMvZGVhbC5kYXJ0JzsK"
    "aW1wb3J0ICdwYWNrYWdlOmludmVudG9yeV9tYW5hZ2VtZW50L21vZGVscy9pbnZlbnRvcnlfYmF0Y2guZGFydCc7"
    "CmltcG9ydCAncGFja2FnZTppbnZlbnRvcnlfbWFuYWdlbWVudC9tb2RlbHMvaW52ZW50b3J5X2l0ZW0uZGFydCc7"
)
out_path = '/Users/keremozkan/Development/inventory_management/test/statistics_service_test.dart'
content = base64.b64decode(b64).decode('utf-8')
with open(out_path, 'w') as f:
    f.write(content)
print('written', len(content), 'bytes')
