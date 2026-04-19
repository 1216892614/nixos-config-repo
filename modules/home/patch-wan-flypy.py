"""Patch moqi_wan_flypy.schema.yaml: enable user dict for frequency tracking and sentence input."""

import sys

schema_path = sys.argv[1]
content = open(schema_path).read()

# Main translator: enable_user_dict for word frequency + enable_sentence for continuous input
# enable_encoder/encode_commit_history are table_translator-only; auto phrase creation
# is already handled by script_translator@user_dict_set and @add_user_dict in the engine.
content = content.replace(
    "enable_user_dict: false # 是否开启自动调频",
    "enable_user_dict: true # 是否开启自动调频\n"
    "  enable_sentence: true # 启用连打/整句输入",
    1,
)

open(schema_path, "w").write(content)
