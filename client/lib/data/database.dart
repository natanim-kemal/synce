import 'package:drift/drift.dart';
import 'native_database.dart';

part 'database.g.dart';

class LocalFiles extends Table {
  TextColumn get id => text()();
  TextColumn get originalName => text()();
  IntColumn get size => integer()();
  TextColumn get hash => text()();
  DateTimeColumn get uploadedAt => dateTime()();
  DateTimeColumn get lastModified => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get localPath => text().nullable()(); // Path to file on device
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))(); // synced, pending, error
  
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [LocalFiles])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(constructDb());

  @override
  int get schemaVersion => 1;
}
