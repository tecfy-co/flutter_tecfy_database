library tecfy_database;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:intl/intl.dart' as intl;

// services
part 'src/services/tecfy_db_service.dart';

// models
part 'src/models/tecfy_collection.model.dart';
part 'src/models/index_field.model.dart';

// utils
part 'src/utils//field_types.util.dart';
