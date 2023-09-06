library tecfy_database;

import 'dart:async';
import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:collection/collection.dart';

// services
part 'src/services/tecfy_db_service.dart';

// models
part 'src/models/tecfy_collection.model.dart';
part 'src/models/index_field.model.dart';
part 'src/models/filter.model.dart';
part 'src/models/listener.model.dart';
part 'src/models/tecfy_collection_operations.model.dart';
part 'src/models/tecfy_document_operations.dart';

// utils
part 'src/utils/field_types.util.dart';

// interfaces
part 'src/interfaces/tecfy_collection.interface.dart';
part 'src/interfaces/tecfy_document.interface.dart';
