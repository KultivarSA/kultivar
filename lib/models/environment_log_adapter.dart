import 'package:hive/hive.dart';
import 'environment_log.dart';

class EnvironmentLogAdapter extends TypeAdapter<EnvironmentLog> {
  @override
  final int typeId = 1;

  @override
  EnvironmentLog read(BinaryReader reader) {
    return EnvironmentLog(
      id: reader.readString(),
      growSpaceId: reader.readString(),
      recordedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      temperature: reader.readBool() ? reader.readDouble() : null,
      humidity: reader.readBool() ? reader.readDouble() : null,
      notes: reader.readBool() ? reader.readString() : null,
    );
  }

  @override
  void write(BinaryWriter writer, EnvironmentLog obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.growSpaceId);
    writer.writeInt(obj.recordedAt.millisecondsSinceEpoch);

    writer.writeBool(obj.temperature != null);
    if (obj.temperature != null) {
      writer.writeDouble(obj.temperature!);
    }

    writer.writeBool(obj.humidity != null);
    if (obj.humidity != null) {
      writer.writeDouble(obj.humidity!);
    }

    writer.writeBool(obj.notes != null);
    if (obj.notes != null) {
      writer.writeString(obj.notes!);
    }
  }
}
