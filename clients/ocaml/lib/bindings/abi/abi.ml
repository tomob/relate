module Description (F : Ctypes.FOREIGN) = struct
  open Ctypes
  open F

  let database = ptr void
  let connection = ptr void
  let query_result = ptr void
  let params = ptr void
  let value = ptr void

  let status = int
  let ll = int64_t
  let i32 = int32_t

  (* uint8_t and size_t as OCaml ints: every use in the ABI is a 0/1 flag or a
     length bounded by the builder's 16 MiB budget, far inside int range. *)
  let uint8 = Views.uint8

  let size_t = Views.size_t

  let err_json = ptr (ptr char)

  let relate_abi_version =
    foreign "relate_abi_version" (void @-> returning status)

  let relate_free_string =
    foreign "relate_free_string" (ptr char @-> returning void)

  let relate_database_open =
    foreign "relate_database_open"
      (string @-> ptr database @-> err_json @-> returning status)

  let relate_database_open_read_only =
    foreign "relate_database_open_read_only"
      (string @-> ptr database @-> err_json @-> returning status)

  let relate_database_close =
    foreign "relate_database_close" (database @-> returning status)

  let relate_connect_namespace =
    foreign "relate_connect_namespace"
      (database @-> string_opt @-> ptr connection @-> err_json @-> returning status)

  let relate_conn_set_namespace =
    foreign "relate_conn_set_namespace"
      (connection @-> string @-> err_json @-> returning status)

  let relate_disconnect =
    foreign "relate_disconnect" (connection @-> returning status)

  let relate_query_params =
    foreign "relate_query_params"
      (connection @-> string @-> params @-> ptr query_result @-> err_json
      @-> returning status)

  let relate_conn_begin =
    foreign "relate_conn_begin" (connection @-> err_json @-> returning status)

  let relate_conn_rollback =
    foreign "relate_conn_rollback" (connection @-> err_json @-> returning status)

  let relate_checkpoint =
    foreign "relate_checkpoint" (database @-> err_json @-> returning status)

  let relate_conn_commit =
    foreign "relate_conn_commit"
      (connection @-> ptr (ptr char) @-> err_json @-> returning status)

  let relate_result_bookmark =
    foreign "relate_result_bookmark" (query_result @-> returning string_opt)

  let relate_result_is_error =
    foreign "relate_result_is_error" (query_result @-> returning uint8)

  let relate_result_error_json =
    foreign "relate_result_error_json" (query_result @-> returning string_opt)

  let relate_column_count =
    foreign "relate_column_count" (query_result @-> returning ll)

  let relate_row_count =
    foreign "relate_row_count" (query_result @-> returning ll)

  let relate_column_name =
    foreign "relate_column_name" (query_result @-> ll @-> returning string)

  let relate_result_query_type =
    foreign "relate_result_query_type" (query_result @-> returning string_opt)

  let relate_result_namespace =
    foreign "relate_result_namespace" (query_result @-> returning string_opt)

  let relate_result_stats =
    foreign "relate_result_stats" (query_result @-> returning string_opt)

  let relate_result_notifications =
    foreign "relate_result_notifications" (query_result @-> returning string_opt)

  let relate_result_plan_json =
    foreign "relate_result_plan_json" (query_result @-> returning string_opt)

  let relate_result_elapsed_ms =
    foreign "relate_result_elapsed_ms" (query_result @-> returning double)

  let relate_result_parse_ms =
    foreign "relate_result_parse_ms" (query_result @-> returning double)

  let relate_result_plan_ms =
    foreign "relate_result_plan_ms" (query_result @-> returning double)

  let relate_result_execute_ms =
    foreign "relate_result_execute_ms" (query_result @-> returning double)

  let relate_value_at =
    foreign "relate_value_at" (query_result @-> ll @-> ll @-> returning (ptr_opt void))

  let relate_value_kind = foreign "relate_value_kind" (value @-> returning int)

  let relate_value_bool =
    foreign "relate_value_bool" (value @-> ptr uint8 @-> returning status)

  let relate_value_int =
    foreign "relate_value_int" (value @-> ptr ll @-> returning status)

  let relate_value_float =
    foreign "relate_value_float" (value @-> ptr double @-> returning status)

  let relate_value_is_nan =
    foreign "relate_value_is_nan" (value @-> ptr uint8 @-> returning status)

  let relate_value_is_inf =
    foreign "relate_value_is_inf" (value @-> ptr uint8 @-> returning status)

  let relate_value_string =
    foreign "relate_value_string" (value @-> ptr size_t @-> returning (ptr char))

  let relate_value_element_id =
    foreign "relate_value_element_id" (value @-> returning string_opt)

  let relate_value_start_element_id =
    foreign "relate_value_start_element_id" (value @-> returning string_opt)

  let relate_value_end_element_id =
    foreign "relate_value_end_element_id" (value @-> returning string_opt)

  let relate_value_id =
    foreign "relate_value_id" (value @-> ptr ll @-> returning status)

  let relate_value_start_id =
    foreign "relate_value_start_id" (value @-> ptr ll @-> returning status)

  let relate_value_end_id =
    foreign "relate_value_end_id" (value @-> ptr ll @-> returning status)

  let relate_value_list_len =
    foreign "relate_value_list_len" (value @-> returning ll)

  let relate_value_list_get =
    foreign "relate_value_list_get" (value @-> ll @-> returning (ptr_opt void))

  let relate_value_map_len =
    foreign "relate_value_map_len" (value @-> returning ll)

  let relate_value_map_key =
    foreign "relate_value_map_key" (value @-> ll @-> ptr size_t @-> returning (ptr char))

  let relate_value_map_get =
    foreign "relate_value_map_get" (value @-> string @-> returning (ptr_opt void))

  let relate_value_year =
    foreign "relate_value_year" (value @-> ptr ll @-> returning status)

  let relate_value_month =
    foreign "relate_value_month" (value @-> ptr ll @-> returning status)

  let relate_value_day =
    foreign "relate_value_day" (value @-> ptr ll @-> returning status)

  let relate_value_hour =
    foreign "relate_value_hour" (value @-> ptr ll @-> returning status)

  let relate_value_minute =
    foreign "relate_value_minute" (value @-> ptr ll @-> returning status)

  let relate_value_second =
    foreign "relate_value_second" (value @-> ptr ll @-> returning status)

  let relate_value_nanosecond =
    foreign "relate_value_nanosecond" (value @-> ptr ll @-> returning status)

  let relate_value_offset_seconds =
    foreign "relate_value_offset_seconds" (value @-> ptr ll @-> returning status)

  let relate_value_zone =
    foreign "relate_value_zone" (value @-> returning string_opt)

  let relate_value_duration =
    foreign "relate_value_duration"
      (value @-> ptr ll @-> ptr ll @-> ptr ll @-> ptr ll @-> returning status)

  let relate_value_point =
    foreign "relate_value_point"
      (value @-> ptr i32 @-> ptr i32 @-> ptr double @-> ptr double @-> ptr double
      @-> returning status)

  let relate_value_vector_dtype =
    foreign "relate_value_vector_dtype" (value @-> returning string_opt)

  let relate_value_vector_dim =
    foreign "relate_value_vector_dim" (value @-> returning ll)

  let relate_value_vector_float =
    foreign "relate_value_vector_float" (value @-> ll @-> ptr double @-> returning status)

  let relate_value_vector_int =
    foreign "relate_value_vector_int" (value @-> ll @-> ptr ll @-> returning status)

  let relate_params_new = foreign "relate_params_new" (void @-> returning params)

  let relate_params_free =
    foreign "relate_params_free" (params @-> returning void)

  let relate_params_put_null =
    foreign "relate_params_put_null"
      (params @-> string_opt @-> err_json @-> returning status)

  let relate_params_put_bool =
    foreign "relate_params_put_bool"
      (params @-> string_opt @-> uint8 @-> err_json @-> returning status)

  let relate_params_put_int =
    foreign "relate_params_put_int"
      (params @-> string_opt @-> ll @-> err_json @-> returning status)

  let relate_params_put_float =
    foreign "relate_params_put_float"
      (params @-> string_opt @-> double @-> err_json @-> returning status)

  let relate_params_put_string =
    foreign "relate_params_put_string"
      (params @-> string_opt @-> string @-> size_t @-> err_json @-> returning status)

  let relate_params_put_date =
    foreign "relate_params_put_date"
      (params @-> string_opt @-> ll @-> ll @-> ll @-> err_json @-> returning status)

  let relate_params_put_time =
    foreign "relate_params_put_time"
      (params @-> string_opt @-> ll @-> ll @-> ll @-> ll @-> ll @-> string_opt
      @-> err_json @-> returning status)

  let relate_params_put_local_time =
    foreign "relate_params_put_local_time"
      (params @-> string_opt @-> ll @-> ll @-> ll @-> ll @-> err_json
      @-> returning status)

  let relate_params_put_datetime =
    foreign "relate_params_put_datetime"
      (params @-> string_opt @-> ll @-> ll @-> ll @-> ll @-> ll @-> ll @-> ll
      @-> ll @-> string_opt @-> err_json @-> returning status)

  let relate_params_put_local_datetime =
    foreign "relate_params_put_local_datetime"
      (params @-> string_opt @-> ll @-> ll @-> ll @-> ll @-> ll @-> ll @-> ll
      @-> err_json @-> returning status)

  let relate_params_put_duration =
    foreign "relate_params_put_duration"
      (params @-> string_opt @-> ll @-> ll @-> ll @-> ll @-> err_json
      @-> returning status)

  let relate_params_put_point =
    foreign "relate_params_put_point"
      (params @-> string_opt @-> i32 @-> double @-> double @-> ptr_opt double
      @-> err_json @-> returning status)

  let relate_params_put_vector_float =
    foreign "relate_params_put_vector_float"
      (params @-> string_opt @-> string @-> ptr double @-> size_t @-> err_json
      @-> returning status)

  let relate_params_put_vector_int =
    foreign "relate_params_put_vector_int"
      (params @-> string_opt @-> string @-> ptr ll @-> size_t @-> err_json
      @-> returning status)

  let relate_params_put_list =
    foreign "relate_params_put_list"
      (params @-> string_opt @-> ptr params @-> err_json @-> returning status)

  let relate_params_put_map =
    foreign "relate_params_put_map"
      (params @-> string_opt @-> ptr params @-> err_json @-> returning status)

  let relate_destroy_result =
    foreign "relate_destroy_result" (query_result @-> returning void)
end
