#
# BSD 3-Clause License
#
# Copyright (c) 2018 - 2023, Oleg Malyavkin
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# DEBUG_TAB redefine this "  " if you need, example: const DEBUG_TAB = "\t"

const PROTO_VERSION = 3

const DEBUG_TAB : String = "  "

enum PB_ERR {
	NO_ERRORS = 0,
	VARINT_NOT_FOUND = -1,
	REPEATED_COUNT_NOT_FOUND = -2,
	REPEATED_COUNT_MISMATCH = -3,
	LENGTHDEL_SIZE_NOT_FOUND = -4,
	LENGTHDEL_SIZE_MISMATCH = -5,
	PACKAGE_SIZE_MISMATCH = -6,
	UNDEFINED_STATE = -7,
	PARSE_INCOMPLETE = -8,
	REQUIRED_FIELDS = -9
}

enum PB_DATA_TYPE {
	INT32 = 0,
	SINT32 = 1,
	UINT32 = 2,
	INT64 = 3,
	SINT64 = 4,
	UINT64 = 5,
	BOOL = 6,
	ENUM = 7,
	FIXED32 = 8,
	SFIXED32 = 9,
	FLOAT = 10,
	FIXED64 = 11,
	SFIXED64 = 12,
	DOUBLE = 13,
	STRING = 14,
	BYTES = 15,
	MESSAGE = 16,
	MAP = 17
}

const DEFAULT_VALUES_2 = {
	PB_DATA_TYPE.INT32: null,
	PB_DATA_TYPE.SINT32: null,
	PB_DATA_TYPE.UINT32: null,
	PB_DATA_TYPE.INT64: null,
	PB_DATA_TYPE.SINT64: null,
	PB_DATA_TYPE.UINT64: null,
	PB_DATA_TYPE.BOOL: null,
	PB_DATA_TYPE.ENUM: null,
	PB_DATA_TYPE.FIXED32: null,
	PB_DATA_TYPE.SFIXED32: null,
	PB_DATA_TYPE.FLOAT: null,
	PB_DATA_TYPE.FIXED64: null,
	PB_DATA_TYPE.SFIXED64: null,
	PB_DATA_TYPE.DOUBLE: null,
	PB_DATA_TYPE.STRING: null,
	PB_DATA_TYPE.BYTES: null,
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: null
}

const DEFAULT_VALUES_3 = {
	PB_DATA_TYPE.INT32: 0,
	PB_DATA_TYPE.SINT32: 0,
	PB_DATA_TYPE.UINT32: 0,
	PB_DATA_TYPE.INT64: 0,
	PB_DATA_TYPE.SINT64: 0,
	PB_DATA_TYPE.UINT64: 0,
	PB_DATA_TYPE.BOOL: false,
	PB_DATA_TYPE.ENUM: 0,
	PB_DATA_TYPE.FIXED32: 0,
	PB_DATA_TYPE.SFIXED32: 0,
	PB_DATA_TYPE.FLOAT: 0.0,
	PB_DATA_TYPE.FIXED64: 0,
	PB_DATA_TYPE.SFIXED64: 0,
	PB_DATA_TYPE.DOUBLE: 0.0,
	PB_DATA_TYPE.STRING: "",
	PB_DATA_TYPE.BYTES: [],
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: []
}

enum PB_TYPE {
	VARINT = 0,
	FIX64 = 1,
	LENGTHDEL = 2,
	STARTGROUP = 3,
	ENDGROUP = 4,
	FIX32 = 5,
	UNDEFINED = 8
}

enum PB_RULE {
	OPTIONAL = 0,
	REQUIRED = 1,
	REPEATED = 2,
	RESERVED = 3
}

enum PB_SERVICE_STATE {
	FILLED = 0,
	UNFILLED = 1
}

class PBField:
	func _init(a_name : String, a_type : int, a_rule : int, a_tag : int, packed : bool, a_value = null):
		name = a_name
		type = a_type
		rule = a_rule
		tag = a_tag
		option_packed = packed
		value = a_value
		
	var name : String
	var type : int
	var rule : int
	var tag : int
	var option_packed : bool
	var value
	var is_map_field : bool = false
	var option_default : bool = false

class PBTypeTag:
	var ok : bool = false
	var type : int
	var tag : int
	var offset : int

class PBServiceField:
	var field : PBField
	var func_ref = null
	var state : int = PB_SERVICE_STATE.UNFILLED

class PBPacker:
	static func convert_signed(n : int) -> int:
		if n < -2147483648:
			return (n << 1) ^ (n >> 63)
		else:
			return (n << 1) ^ (n >> 31)

	static func deconvert_signed(n : int) -> int:
		if n & 0x01:
			return ~(n >> 1)
		else:
			return (n >> 1)

	static func pack_varint(value) -> PackedByteArray:
		var varint : PackedByteArray = PackedByteArray()
		if typeof(value) == TYPE_BOOL:
			if value:
				value = 1
			else:
				value = 0
		for _i in range(9):
			var b = value & 0x7F
			value >>= 7
			if value:
				varint.append(b | 0x80)
			else:
				varint.append(b)
				break
		if varint.size() == 9 && varint[8] == 0xFF:
			varint.append(0x01)
		return varint

	static func pack_bytes(value, count : int, data_type : int) -> PackedByteArray:
		var bytes : PackedByteArray = PackedByteArray()
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_float(value)
			bytes = spb.get_data_array()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_double(value)
			bytes = spb.get_data_array()
		else:
			for _i in range(count):
				bytes.append(value & 0xFF)
				value >>= 8
		return bytes

	static func unpack_bytes(bytes : PackedByteArray, index : int, count : int, data_type : int):
		var value = 0
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			for i in range(index, count + index):
				spb.put_u8(bytes[i])
			spb.seek(0)
			value = spb.get_float()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			for i in range(index, count + index):
				spb.put_u8(bytes[i])
			spb.seek(0)
			value = spb.get_double()
		else:
			for i in range(index + count - 1, index - 1, -1):
				value |= (bytes[i] & 0xFF)
				if i != index:
					value <<= 8
		return value

	static func unpack_varint(varint_bytes) -> int:
		var value : int = 0
		for i in range(varint_bytes.size() - 1, -1, -1):
			value |= varint_bytes[i] & 0x7F
			if i != 0:
				value <<= 7
		return value

	static func pack_type_tag(type : int, tag : int) -> PackedByteArray:
		return pack_varint((tag << 3) | type)

	static func isolate_varint(bytes : PackedByteArray, index : int) -> PackedByteArray:
		var result : PackedByteArray = PackedByteArray()
		for i in range(index, bytes.size()):
			result.append(bytes[i])
			if !(bytes[i] & 0x80):
				break
		return result

	static func unpack_type_tag(bytes : PackedByteArray, index : int) -> PBTypeTag:
		var varint_bytes : PackedByteArray = isolate_varint(bytes, index)
		var result : PBTypeTag = PBTypeTag.new()
		if varint_bytes.size() != 0:
			result.ok = true
			result.offset = varint_bytes.size()
			var unpacked : int = unpack_varint(varint_bytes)
			result.type = unpacked & 0x07
			result.tag = unpacked >> 3
		return result

	static func pack_length_delimeted(type : int, tag : int, bytes : PackedByteArray) -> PackedByteArray:
		var result : PackedByteArray = pack_type_tag(type, tag)
		result.append_array(pack_varint(bytes.size()))
		result.append_array(bytes)
		return result

	static func pb_type_from_data_type(data_type : int) -> int:
		if data_type == PB_DATA_TYPE.INT32 || data_type == PB_DATA_TYPE.SINT32 || data_type == PB_DATA_TYPE.UINT32 || data_type == PB_DATA_TYPE.INT64 || data_type == PB_DATA_TYPE.SINT64 || data_type == PB_DATA_TYPE.UINT64 || data_type == PB_DATA_TYPE.BOOL || data_type == PB_DATA_TYPE.ENUM:
			return PB_TYPE.VARINT
		elif data_type == PB_DATA_TYPE.FIXED32 || data_type == PB_DATA_TYPE.SFIXED32 || data_type == PB_DATA_TYPE.FLOAT:
			return PB_TYPE.FIX32
		elif data_type == PB_DATA_TYPE.FIXED64 || data_type == PB_DATA_TYPE.SFIXED64 || data_type == PB_DATA_TYPE.DOUBLE:
			return PB_TYPE.FIX64
		elif data_type == PB_DATA_TYPE.STRING || data_type == PB_DATA_TYPE.BYTES || data_type == PB_DATA_TYPE.MESSAGE || data_type == PB_DATA_TYPE.MAP:
			return PB_TYPE.LENGTHDEL
		else:
			return PB_TYPE.UNDEFINED

	static func pack_field(field : PBField) -> PackedByteArray:
		var type : int = pb_type_from_data_type(field.type)
		var type_copy : int = type
		if field.rule == PB_RULE.REPEATED && field.option_packed:
			type = PB_TYPE.LENGTHDEL
		var head : PackedByteArray = pack_type_tag(type, field.tag)
		var data : PackedByteArray = PackedByteArray()
		if type == PB_TYPE.VARINT:
			var value
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						value = convert_signed(v)
					else:
						value = v
					data.append_array(pack_varint(value))
				return data
			else:
				if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
					value = convert_signed(field.value)
				else:
					value = field.value
				data = pack_varint(value)
		elif type == PB_TYPE.FIX32:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 4, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 4, field.type))
		elif type == PB_TYPE.FIX64:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 8, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 8, field.type))
		elif type == PB_TYPE.LENGTHDEL:
			if field.rule == PB_RULE.REPEATED:
				if type_copy == PB_TYPE.VARINT:
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						var signed_value : int
						for v in field.value:
							signed_value = convert_signed(v)
							data.append_array(pack_varint(signed_value))
					else:
						for v in field.value:
							data.append_array(pack_varint(v))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX32:
					for v in field.value:
						data.append_array(pack_bytes(v, 4, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX64:
					for v in field.value:
						data.append_array(pack_bytes(v, 8, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif field.type == PB_DATA_TYPE.STRING:
					for v in field.value:
						var obj = v.to_utf8_buffer()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
				elif field.type == PB_DATA_TYPE.BYTES:
					for v in field.value:
						data.append_array(pack_length_delimeted(type, field.tag, v))
					return data
				elif typeof(field.value[0]) == TYPE_OBJECT:
					for v in field.value:
						var obj : PackedByteArray = v.to_bytes()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
			else:
				if field.type == PB_DATA_TYPE.STRING:
					var str_bytes : PackedByteArray = field.value.to_utf8_buffer()
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && str_bytes.size() > 0):
						data.append_array(str_bytes)
						return pack_length_delimeted(type, field.tag, data)
				if field.type == PB_DATA_TYPE.BYTES:
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && field.value.size() > 0):
						data.append_array(field.value)
						return pack_length_delimeted(type, field.tag, data)
				elif typeof(field.value) == TYPE_OBJECT:
					var obj : PackedByteArray = field.value.to_bytes()
					if obj.size() > 0:
						data.append_array(obj)
					return pack_length_delimeted(type, field.tag, data)
				else:
					pass
		if data.size() > 0:
			head.append_array(data)
			return head
		else:
			return data

	static func unpack_field(bytes : PackedByteArray, offset : int, field : PBField, type : int, message_func_ref) -> int:
		if field.rule == PB_RULE.REPEATED && type != PB_TYPE.LENGTHDEL && field.option_packed:
			var count = isolate_varint(bytes, offset)
			if count.size() > 0:
				offset += count.size()
				count = unpack_varint(count)
				if type == PB_TYPE.VARINT:
					var val
					var counter = offset + count
					while offset < counter:
						val = isolate_varint(bytes, offset)
						if val.size() > 0:
							offset += val.size()
							val = unpack_varint(val)
							if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
								val = deconvert_signed(val)
							elif field.type == PB_DATA_TYPE.BOOL:
								if val:
									val = true
								else:
									val = false
							field.value.append(val)
						else:
							return PB_ERR.REPEATED_COUNT_MISMATCH
					return offset
				elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
					var type_size
					if type == PB_TYPE.FIX32:
						type_size = 4
					else:
						type_size = 8
					var val
					var counter = offset + count
					while offset < counter:
						if (offset + type_size) > bytes.size():
							return PB_ERR.REPEATED_COUNT_MISMATCH
						val = unpack_bytes(bytes, offset, type_size, field.type)
						offset += type_size
						field.value.append(val)
					return offset
			else:
				return PB_ERR.REPEATED_COUNT_NOT_FOUND
		else:
			if type == PB_TYPE.VARINT:
				var val = isolate_varint(bytes, offset)
				if val.size() > 0:
					offset += val.size()
					val = unpack_varint(val)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						val = deconvert_signed(val)
					elif field.type == PB_DATA_TYPE.BOOL:
						if val:
							val = true
						else:
							val = false
					if field.rule == PB_RULE.REPEATED:
						field.value.append(val)
					else:
						field.value = val
				else:
					return PB_ERR.VARINT_NOT_FOUND
				return offset
			elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
				var type_size
				if type == PB_TYPE.FIX32:
					type_size = 4
				else:
					type_size = 8
				var val
				if (offset + type_size) > bytes.size():
					return PB_ERR.REPEATED_COUNT_MISMATCH
				val = unpack_bytes(bytes, offset, type_size, field.type)
				offset += type_size
				if field.rule == PB_RULE.REPEATED:
					field.value.append(val)
				else:
					field.value = val
				return offset
			elif type == PB_TYPE.LENGTHDEL:
				var inner_size = isolate_varint(bytes, offset)
				if inner_size.size() > 0:
					offset += inner_size.size()
					inner_size = unpack_varint(inner_size)
					if inner_size >= 0:
						if inner_size + offset > bytes.size():
							return PB_ERR.LENGTHDEL_SIZE_MISMATCH
						if message_func_ref != null:
							var message = message_func_ref.call()
							if inner_size > 0:
								var sub_offset = message.from_bytes(bytes, offset, inner_size + offset)
								if sub_offset > 0:
									if sub_offset - offset >= inner_size:
										offset = sub_offset
										return offset
									else:
										return PB_ERR.LENGTHDEL_SIZE_MISMATCH
								return sub_offset
							else:
								return offset
						elif field.type == PB_DATA_TYPE.STRING:
							var str_bytes : PackedByteArray = PackedByteArray()
							for i in range(offset, inner_size + offset):
								str_bytes.append(bytes[i])
							if field.rule == PB_RULE.REPEATED:
								field.value.append(str_bytes.get_string_from_utf8())
							else:
								field.value = str_bytes.get_string_from_utf8()
							return offset + inner_size
						elif field.type == PB_DATA_TYPE.BYTES:
							var val_bytes : PackedByteArray = PackedByteArray()
							for i in range(offset, inner_size + offset):
								val_bytes.append(bytes[i])
							if field.rule == PB_RULE.REPEATED:
								field.value.append(val_bytes)
							else:
								field.value = val_bytes
							return offset + inner_size
					else:
						return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
				else:
					return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
		return PB_ERR.UNDEFINED_STATE

	static func unpack_message(data, bytes : PackedByteArray, offset : int, limit : int) -> int:
		while true:
			var tt : PBTypeTag = unpack_type_tag(bytes, offset)
			if tt.ok:
				offset += tt.offset
				if data.has(tt.tag):
					var service : PBServiceField = data[tt.tag]
					var type : int = pb_type_from_data_type(service.field.type)
					if type == tt.type || (tt.type == PB_TYPE.LENGTHDEL && service.field.rule == PB_RULE.REPEATED && service.field.option_packed):
						var res : int = unpack_field(bytes, offset, service.field, type, service.func_ref)
						if res > 0:
							service.state = PB_SERVICE_STATE.FILLED
							offset = res
							if offset == limit:
								return offset
							elif offset > limit:
								return PB_ERR.PACKAGE_SIZE_MISMATCH
						elif res < 0:
							return res
						else:
							break
			else:
				return offset
		return PB_ERR.UNDEFINED_STATE

	static func pack_message(data) -> PackedByteArray:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : PackedByteArray = PackedByteArray()
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result.append_array(pack_field(data[i].field))
			elif data[i].field.rule == PB_RULE.REQUIRED:
				print("Error: required field is not filled: Tag:", data[i].field.tag)
				return PackedByteArray()
		return result

	static func check_required(data) -> bool:
		var keys : Array = data.keys()
		for i in keys:
			if data[i].field.rule == PB_RULE.REQUIRED && data[i].state == PB_SERVICE_STATE.UNFILLED:
				return false
		return true

	static func construct_map(key_values):
		var result = {}
		for kv in key_values:
			result[kv.get_key()] = kv.get_value()
		return result
	
	static func tabulate(text : String, nesting : int) -> String:
		var tab : String = ""
		for _i in range(nesting):
			tab += DEBUG_TAB
		return tab + text
	
	static func value_to_string(value, field : PBField, nesting : int) -> String:
		var result : String = ""
		var text : String
		if field.type == PB_DATA_TYPE.MESSAGE:
			result += "{"
			nesting += 1
			text = message_to_string(value.data, nesting)
			if text != "":
				result += "\n" + text
				nesting -= 1
				result += tabulate("}", nesting)
			else:
				nesting -= 1
				result += "}"
		elif field.type == PB_DATA_TYPE.BYTES:
			result += "<"
			for i in range(value.size()):
				result += str(value[i])
				if i != (value.size() - 1):
					result += ", "
			result += ">"
		elif field.type == PB_DATA_TYPE.STRING:
			result += "\"" + value + "\""
		elif field.type == PB_DATA_TYPE.ENUM:
			result += "ENUM::" + str(value)
		else:
			result += str(value)
		return result
	
	static func field_to_string(field : PBField, nesting : int) -> String:
		var result : String = tabulate(field.name + ": ", nesting)
		if field.type == PB_DATA_TYPE.MAP:
			if field.value.size() > 0:
				result += "(\n"
				nesting += 1
				for i in range(field.value.size()):
					var local_key_value = field.value[i].data[1].field
					result += tabulate(value_to_string(local_key_value.value, local_key_value, nesting), nesting) + ": "
					local_key_value = field.value[i].data[2].field
					result += value_to_string(local_key_value.value, local_key_value, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate(")", nesting)
			else:
				result += "()"
		elif field.rule == PB_RULE.REPEATED:
			if field.value.size() > 0:
				result += "[\n"
				nesting += 1
				for i in range(field.value.size()):
					result += tabulate(str(i) + ": ", nesting)
					result += value_to_string(field.value[i], field, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate("]", nesting)
			else:
				result += "[]"
		else:
			result += value_to_string(field.value, field, nesting)
		result += ";\n"
		return result
		
	static func message_to_string(data, nesting : int = 0) -> String:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : String = ""
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result += field_to_string(data[i].field, nesting)
			elif data[i].field.rule == PB_RULE.REQUIRED:
				result += data[i].field.name + ": " + "error"
		return result



############### USER DATA BEGIN ################


class Response:
	func _init():
		var service
		
		_success = PBField.new("success", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = _success
		data[_success.tag] = service
		
		_msg = PBField.new("msg", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _msg
		data[_msg.tag] = service
		
	var data = {}
	
	var _success: PBField
	func get_success() -> bool:
		return _success.value
	func clear_success() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_success.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_success(value : bool) -> void:
		_success.value = value
	
	var _msg: PBField
	func has_msg() -> bool:
		return data[2].state == PB_SERVICE_STATE.FILLED
	func get_msg() -> String:
		return _msg.value
	func clear_msg() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_msg.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_msg(value : String) -> void:
		data[2].state = PB_SERVICE_STATE.FILLED
		_msg.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ClientId:
	func _init():
		var service
		
		_id = PBField.new("id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = _id
		data[_id.tag] = service
		
	var data = {}
	
	var _id: PBField
	func get_id() -> int:
		return _id.value
	func clear_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_id(value : int) -> void:
		_id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class LoginRequest:
	func _init():
		var service
		
		_username = PBField.new("username", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _username
		data[_username.tag] = service
		
		_password = PBField.new("password", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _password
		data[_password.tag] = service
		
	var data = {}
	
	var _username: PBField
	func get_username() -> String:
		return _username.value
	func clear_username() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_username.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_username(value : String) -> void:
		_username.value = value
	
	var _password: PBField
	func get_password() -> String:
		return _password.value
	func clear_password() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_password.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_password(value : String) -> void:
		_password.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class LoginResponse:
	func _init():
		var service
		
		_response = PBField.new("response", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _response
		service.func_ref = Callable(self, "new_response")
		data[_response.tag] = service
		
	var data = {}
	
	var _response: PBField
	func get_response() -> Response:
		return _response.value
	func clear_response() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_response() -> Response:
		_response.value = Response.new()
		return _response.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RegisterRequest:
	func _init():
		var service
		
		_username = PBField.new("username", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _username
		data[_username.tag] = service
		
		_password = PBField.new("password", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _password
		data[_password.tag] = service
		
	var data = {}
	
	var _username: PBField
	func get_username() -> String:
		return _username.value
	func clear_username() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_username.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_username(value : String) -> void:
		_username.value = value
	
	var _password: PBField
	func get_password() -> String:
		return _password.value
	func clear_password() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_password.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_password(value : String) -> void:
		_password.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class RegisterResponse:
	func _init():
		var service
		
		_response = PBField.new("response", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _response
		service.func_ref = Callable(self, "new_response")
		data[_response.tag] = service
		
	var data = {}
	
	var _response: PBField
	func get_response() -> Response:
		return _response.value
	func clear_response() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_response() -> Response:
		_response.value = Response.new()
		return _response.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Logout:
	func _init():
		var service
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Chat:
	func _init():
		var service
		
		_msg = PBField.new("msg", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _msg
		data[_msg.tag] = service
		
	var data = {}
	
	var _msg: PBField
	func get_msg() -> String:
		return _msg.value
	func clear_msg() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_msg.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_msg(value : String) -> void:
		_msg.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Yell:
	func _init():
		var service
		
		_sender_name = PBField.new("sender_name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _sender_name
		data[_sender_name.tag] = service
		
		_msg = PBField.new("msg", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _msg
		data[_msg.tag] = service
		
	var data = {}
	
	var _sender_name: PBField
	func get_sender_name() -> String:
		return _sender_name.value
	func clear_sender_name() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_sender_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_sender_name(value : String) -> void:
		_sender_name.value = value
	
	var _msg: PBField
	func get_msg() -> String:
		return _msg.value
	func clear_msg() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_msg.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_msg(value : String) -> void:
		_msg.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Actor:
	func _init():
		var service
		
		_id = PBField.new("id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = _id
		data[_id.tag] = service
		
		_x = PBField.new("x", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _x
		data[_x.tag] = service
		
		_y = PBField.new("y", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _y
		data[_y.tag] = service
		
		_name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _name
		data[_name.tag] = service
		
	var data = {}
	
	var _id: PBField
	func get_id() -> int:
		return _id.value
	func clear_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_id(value : int) -> void:
		_id.value = value
	
	var _x: PBField
	func get_x() -> int:
		return _x.value
	func clear_x() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_x(value : int) -> void:
		_x.value = value
	
	var _y: PBField
	func get_y() -> int:
		return _y.value
	func clear_y() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_y(value : int) -> void:
		_y.value = value
	
	var _name: PBField
	func get_name() -> String:
		return _name.value
	func clear_name() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		_name.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ActorMove:
	func _init():
		var service
		
		_dx = PBField.new("dx", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _dx
		data[_dx.tag] = service
		
		_dy = PBField.new("dy", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _dy
		data[_dy.tag] = service
		
	var data = {}
	
	var _dx: PBField
	func get_dx() -> int:
		return _dx.value
	func clear_dx() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_dx.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_dx(value : int) -> void:
		_dx.value = value
	
	var _dy: PBField
	func get_dy() -> int:
		return _dy.value
	func clear_dy() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_dy.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_dy(value : int) -> void:
		_dy.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Motd:
	func _init():
		var service
		
		_msg = PBField.new("msg", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _msg
		data[_msg.tag] = service
		
	var data = {}
	
	var _msg: PBField
	func get_msg() -> String:
		return _msg.value
	func clear_msg() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_msg.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_msg(value : String) -> void:
		_msg.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Disconnect:
	func _init():
		var service
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class AdminLoginGranted:
	func _init():
		var service
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class SqlQuery:
	func _init():
		var service
		
		_query = PBField.new("query", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _query
		data[_query.tag] = service
		
	var data = {}
	
	var _query: PBField
	func get_query() -> String:
		return _query.value
	func clear_query() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_query(value : String) -> void:
		_query.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class SqlRow:
	func _init():
		var service
		
		_values = PBField.new("values", PB_DATA_TYPE.STRING, PB_RULE.REPEATED, 1, true, [])
		service = PBServiceField.new()
		service.field = _values
		data[_values.tag] = service
		
	var data = {}
	
	var _values: PBField
	func get_values() -> Array:
		return _values.value
	func clear_values() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_values.value = []
	func add_values(value : String) -> void:
		_values.value.append(value)
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class SqlResponse:
	func _init():
		var service
		
		_response = PBField.new("response", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _response
		service.func_ref = Callable(self, "new_response")
		data[_response.tag] = service
		
		_columns = PBField.new("columns", PB_DATA_TYPE.STRING, PB_RULE.REPEATED, 2, true, [])
		service = PBServiceField.new()
		service.field = _columns
		data[_columns.tag] = service
		
		_rows = PBField.new("rows", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 3, true, [])
		service = PBServiceField.new()
		service.field = _rows
		service.func_ref = Callable(self, "add_rows")
		data[_rows.tag] = service
		
	var data = {}
	
	var _response: PBField
	func get_response() -> Response:
		return _response.value
	func clear_response() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_response() -> Response:
		_response.value = Response.new()
		return _response.value
	
	var _columns: PBField
	func get_columns() -> Array:
		return _columns.value
	func clear_columns() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_columns.value = []
	func add_columns(value : String) -> void:
		_columns.value.append(value)
	
	var _rows: PBField
	func get_rows() -> Array:
		return _rows.value
	func clear_rows() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_rows.value = []
	func add_rows() -> SqlRow:
		var element = SqlRow.new()
		_rows.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class CollisionPoint:
	func _init():
		var service
		
		_x = PBField.new("x", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _x
		data[_x.tag] = service
		
		_y = PBField.new("y", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _y
		data[_y.tag] = service
		
	var data = {}
	
	var _x: PBField
	func get_x() -> int:
		return _x.value
	func clear_x() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_x(value : int) -> void:
		_x.value = value
	
	var _y: PBField
	func get_y() -> int:
		return _y.value
	func clear_y() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_y(value : int) -> void:
		_y.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Shrub:
	func _init():
		var service
		
		_id = PBField.new("id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = _id
		data[_id.tag] = service
		
		_x = PBField.new("x", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _x
		data[_x.tag] = service
		
		_y = PBField.new("y", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _y
		data[_y.tag] = service
		
		_strength = PBField.new("strength", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _strength
		data[_strength.tag] = service
		
	var data = {}
	
	var _id: PBField
	func get_id() -> int:
		return _id.value
	func clear_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_id(value : int) -> void:
		_id.value = value
	
	var _x: PBField
	func get_x() -> int:
		return _x.value
	func clear_x() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_x(value : int) -> void:
		_x.value = value
	
	var _y: PBField
	func get_y() -> int:
		return _y.value
	func clear_y() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_y(value : int) -> void:
		_y.value = value
	
	var _strength: PBField
	func get_strength() -> int:
		return _strength.value
	func clear_strength() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_strength.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_strength(value : int) -> void:
		_strength.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Door:
	func _init():
		var service
		
		_id = PBField.new("id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = _id
		data[_id.tag] = service
		
		_destination_level_gd_res_path = PBField.new("destination_level_gd_res_path", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _destination_level_gd_res_path
		data[_destination_level_gd_res_path.tag] = service
		
		_destination_x = PBField.new("destination_x", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _destination_x
		data[_destination_x.tag] = service
		
		_destination_y = PBField.new("destination_y", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _destination_y
		data[_destination_y.tag] = service
		
		_x = PBField.new("x", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _x
		data[_x.tag] = service
		
		_y = PBField.new("y", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _y
		data[_y.tag] = service
		
	var data = {}
	
	var _id: PBField
	func get_id() -> int:
		return _id.value
	func clear_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_id(value : int) -> void:
		_id.value = value
	
	var _destination_level_gd_res_path: PBField
	func get_destination_level_gd_res_path() -> String:
		return _destination_level_gd_res_path.value
	func clear_destination_level_gd_res_path() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_destination_level_gd_res_path.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_destination_level_gd_res_path(value : String) -> void:
		_destination_level_gd_res_path.value = value
	
	var _destination_x: PBField
	func get_destination_x() -> int:
		return _destination_x.value
	func clear_destination_x() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_destination_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_destination_x(value : int) -> void:
		_destination_x.value = value
	
	var _destination_y: PBField
	func get_destination_y() -> int:
		return _destination_y.value
	func clear_destination_y() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_destination_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_destination_y(value : int) -> void:
		_destination_y.value = value
	
	var _x: PBField
	func get_x() -> int:
		return _x.value
	func clear_x() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_x(value : int) -> void:
		_x.value = value
	
	var _y: PBField
	func get_y() -> int:
		return _y.value
	func clear_y() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_y(value : int) -> void:
		_y.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
enum Harvestable {
	NONE = 0,
	SHRUB = 1
}

class ToolProps:
	func _init():
		var service
		
		_strength = PBField.new("strength", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _strength
		data[_strength.tag] = service
		
		_level_required = PBField.new("level_required", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _level_required
		data[_level_required.tag] = service
		
		_harvests = PBField.new("harvests", PB_DATA_TYPE.ENUM, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM])
		service = PBServiceField.new()
		service.field = _harvests
		data[_harvests.tag] = service
		
	var data = {}
	
	var _strength: PBField
	func get_strength() -> int:
		return _strength.value
	func clear_strength() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_strength.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_strength(value : int) -> void:
		_strength.value = value
	
	var _level_required: PBField
	func get_level_required() -> int:
		return _level_required.value
	func clear_level_required() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_level_required.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_level_required(value : int) -> void:
		_level_required.value = value
	
	var _harvests: PBField
	func get_harvests():
		return _harvests.value
	func clear_harvests() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_harvests.value = DEFAULT_VALUES_3[PB_DATA_TYPE.ENUM]
	func set_harvests(value) -> void:
		_harvests.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Item:
	func _init():
		var service
		
		_name = PBField.new("name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _name
		data[_name.tag] = service
		
		_description = PBField.new("description", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _description
		data[_description.tag] = service
		
		_sprite_region_x = PBField.new("sprite_region_x", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _sprite_region_x
		data[_sprite_region_x.tag] = service
		
		_sprite_region_y = PBField.new("sprite_region_y", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _sprite_region_y
		data[_sprite_region_y.tag] = service
		
		_tool_props = PBField.new("tool_props", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _tool_props
		service.func_ref = Callable(self, "new_tool_props")
		data[_tool_props.tag] = service
		
	var data = {}
	
	var _name: PBField
	func get_name() -> String:
		return _name.value
	func clear_name() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_name(value : String) -> void:
		_name.value = value
	
	var _description: PBField
	func get_description() -> String:
		return _description.value
	func clear_description() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_description.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_description(value : String) -> void:
		_description.value = value
	
	var _sprite_region_x: PBField
	func get_sprite_region_x() -> int:
		return _sprite_region_x.value
	func clear_sprite_region_x() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_sprite_region_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_sprite_region_x(value : int) -> void:
		_sprite_region_x.value = value
	
	var _sprite_region_y: PBField
	func get_sprite_region_y() -> int:
		return _sprite_region_y.value
	func clear_sprite_region_y() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_sprite_region_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_sprite_region_y(value : int) -> void:
		_sprite_region_y.value = value
	
	var _tool_props: PBField
	func get_tool_props() -> ToolProps:
		return _tool_props.value
	func clear_tool_props() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_tool_props.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_tool_props() -> ToolProps:
		_tool_props.value = ToolProps.new()
		return _tool_props.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class GroundItem:
	func _init():
		var service
		
		_id = PBField.new("id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = _id
		data[_id.tag] = service
		
		_item = PBField.new("item", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _item
		service.func_ref = Callable(self, "new_item")
		data[_item.tag] = service
		
		_x = PBField.new("x", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _x
		data[_x.tag] = service
		
		_y = PBField.new("y", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _y
		data[_y.tag] = service
		
		_respawn_seconds = PBField.new("respawn_seconds", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _respawn_seconds
		data[_respawn_seconds.tag] = service
		
	var data = {}
	
	var _id: PBField
	func get_id() -> int:
		return _id.value
	func clear_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_id(value : int) -> void:
		_id.value = value
	
	var _item: PBField
	func get_item() -> Item:
		return _item.value
	func clear_item() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_item() -> Item:
		_item.value = Item.new()
		return _item.value
	
	var _x: PBField
	func get_x() -> int:
		return _x.value
	func clear_x() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_x(value : int) -> void:
		_x.value = value
	
	var _y: PBField
	func get_y() -> int:
		return _y.value
	func clear_y() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_y(value : int) -> void:
		_y.value = value
	
	var _respawn_seconds: PBField
	func get_respawn_seconds() -> int:
		return _respawn_seconds.value
	func clear_respawn_seconds() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_respawn_seconds.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_respawn_seconds(value : int) -> void:
		_respawn_seconds.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class LevelUpload:
	func _init():
		var service
		
		_gd_res_path = PBField.new("gd_res_path", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _gd_res_path
		data[_gd_res_path.tag] = service
		
		_tscn_data = PBField.new("tscn_data", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = _tscn_data
		data[_tscn_data.tag] = service
		
		_collision_point = PBField.new("collision_point", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 3, true, [])
		service = PBServiceField.new()
		service.field = _collision_point
		service.func_ref = Callable(self, "add_collision_point")
		data[_collision_point.tag] = service
		
		_shrub = PBField.new("shrub", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 4, true, [])
		service = PBServiceField.new()
		service.field = _shrub
		service.func_ref = Callable(self, "add_shrub")
		data[_shrub.tag] = service
		
		_door = PBField.new("door", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 5, true, [])
		service = PBServiceField.new()
		service.field = _door
		service.func_ref = Callable(self, "add_door")
		data[_door.tag] = service
		
		_ground_item = PBField.new("ground_item", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 6, true, [])
		service = PBServiceField.new()
		service.field = _ground_item
		service.func_ref = Callable(self, "add_ground_item")
		data[_ground_item.tag] = service
		
	var data = {}
	
	var _gd_res_path: PBField
	func get_gd_res_path() -> String:
		return _gd_res_path.value
	func clear_gd_res_path() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_gd_res_path.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_gd_res_path(value : String) -> void:
		_gd_res_path.value = value
	
	var _tscn_data: PBField
	func get_tscn_data() -> PackedByteArray:
		return _tscn_data.value
	func clear_tscn_data() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_tscn_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_tscn_data(value : PackedByteArray) -> void:
		_tscn_data.value = value
	
	var _collision_point: PBField
	func get_collision_point() -> Array:
		return _collision_point.value
	func clear_collision_point() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_collision_point.value = []
	func add_collision_point() -> CollisionPoint:
		var element = CollisionPoint.new()
		_collision_point.value.append(element)
		return element
	
	var _shrub: PBField
	func get_shrub() -> Array:
		return _shrub.value
	func clear_shrub() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = []
	func add_shrub() -> Shrub:
		var element = Shrub.new()
		_shrub.value.append(element)
		return element
	
	var _door: PBField
	func get_door() -> Array:
		return _door.value
	func clear_door() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_door.value = []
	func add_door() -> Door:
		var element = Door.new()
		_door.value.append(element)
		return element
	
	var _ground_item: PBField
	func get_ground_item() -> Array:
		return _ground_item.value
	func clear_ground_item() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = []
	func add_ground_item() -> GroundItem:
		var element = GroundItem.new()
		_ground_item.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class LevelUploadResponse:
	func _init():
		var service
		
		_db_level_id = PBField.new("db_level_id", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _db_level_id
		data[_db_level_id.tag] = service
		
		_gd_res_path = PBField.new("gd_res_path", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _gd_res_path
		data[_gd_res_path.tag] = service
		
		_response = PBField.new("response", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _response
		service.func_ref = Callable(self, "new_response")
		data[_response.tag] = service
		
	var data = {}
	
	var _db_level_id: PBField
	func get_db_level_id() -> int:
		return _db_level_id.value
	func clear_db_level_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_db_level_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_db_level_id(value : int) -> void:
		_db_level_id.value = value
	
	var _gd_res_path: PBField
	func get_gd_res_path() -> String:
		return _gd_res_path.value
	func clear_gd_res_path() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_gd_res_path.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_gd_res_path(value : String) -> void:
		_gd_res_path.value = value
	
	var _response: PBField
	func get_response() -> Response:
		return _response.value
	func clear_response() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_response() -> Response:
		_response.value = Response.new()
		return _response.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class LevelDownload:
	func _init():
		var service
		
		_data = PBField.new("data", PB_DATA_TYPE.BYTES, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES])
		service = PBServiceField.new()
		service.field = _data
		data[_data.tag] = service
		
	var data = {}
	
	var _data: PBField
	func get_data() -> PackedByteArray:
		return _data.value
	func clear_data() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_data.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BYTES]
	func set_data(value : PackedByteArray) -> void:
		_data.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class AdminJoinGameRequest:
	func _init():
		var service
		
	var data = {}
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class AdminJoinGameResponse:
	func _init():
		var service
		
		_response = PBField.new("response", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _response
		service.func_ref = Callable(self, "new_response")
		data[_response.tag] = service
		
	var data = {}
	
	var _response: PBField
	func get_response() -> Response:
		return _response.value
	func clear_response() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_response() -> Response:
		_response.value = Response.new()
		return _response.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ServerMessage:
	func _init():
		var service
		
		_msg = PBField.new("msg", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = _msg
		data[_msg.tag] = service
		
	var data = {}
	
	var _msg: PBField
	func get_msg() -> String:
		return _msg.value
	func clear_msg() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_msg.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_msg(value : String) -> void:
		_msg.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class PickupGroundItemRequest:
	func _init():
		var service
		
		_ground_item_id = PBField.new("ground_item_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = _ground_item_id
		data[_ground_item_id.tag] = service
		
	var data = {}
	
	var _ground_item_id: PBField
	func get_ground_item_id() -> int:
		return _ground_item_id.value
	func clear_ground_item_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_ground_item_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_ground_item_id(value : int) -> void:
		_ground_item_id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class PickupGroundItemResponse:
	func _init():
		var service
		
		_ground_item = PBField.new("ground_item", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _ground_item
		service.func_ref = Callable(self, "new_ground_item")
		data[_ground_item.tag] = service
		
		_response = PBField.new("response", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _response
		service.func_ref = Callable(self, "new_response")
		data[_response.tag] = service
		
	var data = {}
	
	var _ground_item: PBField
	func get_ground_item() -> GroundItem:
		return _ground_item.value
	func clear_ground_item() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_ground_item() -> GroundItem:
		_ground_item.value = GroundItem.new()
		return _ground_item.value
	
	var _response: PBField
	func get_response() -> Response:
		return _response.value
	func clear_response() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_response() -> Response:
		_response.value = Response.new()
		return _response.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class DropItemRequest:
	func _init():
		var service
		
		_item = PBField.new("item", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _item
		service.func_ref = Callable(self, "new_item")
		data[_item.tag] = service
		
		_quantity = PBField.new("quantity", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = _quantity
		data[_quantity.tag] = service
		
	var data = {}
	
	var _item: PBField
	func get_item() -> Item:
		return _item.value
	func clear_item() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_item() -> Item:
		_item.value = Item.new()
		return _item.value
	
	var _quantity: PBField
	func get_quantity() -> int:
		return _quantity.value
	func clear_quantity() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_quantity(value : int) -> void:
		_quantity.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class DropItemResponse:
	func _init():
		var service
		
		_item = PBField.new("item", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _item
		service.func_ref = Callable(self, "new_item")
		data[_item.tag] = service
		
		_quantity = PBField.new("quantity", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = _quantity
		data[_quantity.tag] = service
		
		_response = PBField.new("response", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _response
		service.func_ref = Callable(self, "new_response")
		data[_response.tag] = service
		
	var data = {}
	
	var _item: PBField
	func get_item() -> Item:
		return _item.value
	func clear_item() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_item() -> Item:
		_item.value = Item.new()
		return _item.value
	
	var _quantity: PBField
	func get_quantity() -> int:
		return _quantity.value
	func clear_quantity() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_quantity(value : int) -> void:
		_quantity.value = value
	
	var _response: PBField
	func get_response() -> Response:
		return _response.value
	func clear_response() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_response() -> Response:
		_response.value = Response.new()
		return _response.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ItemQuantity:
	func _init():
		var service
		
		_item = PBField.new("item", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _item
		service.func_ref = Callable(self, "new_item")
		data[_item.tag] = service
		
		_quantity = PBField.new("quantity", PB_DATA_TYPE.INT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT32])
		service = PBServiceField.new()
		service.field = _quantity
		data[_quantity.tag] = service
		
	var data = {}
	
	var _item: PBField
	func get_item() -> Item:
		return _item.value
	func clear_item() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_item() -> Item:
		_item.value = Item.new()
		return _item.value
	
	var _quantity: PBField
	func get_quantity() -> int:
		return _quantity.value
	func clear_quantity() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT32]
	func set_quantity(value : int) -> void:
		_quantity.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ActorInventory:
	func _init():
		var service
		
		_items_quantities = PBField.new("items_quantities", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, [])
		service = PBServiceField.new()
		service.field = _items_quantities
		service.func_ref = Callable(self, "add_items_quantities")
		data[_items_quantities.tag] = service
		
	var data = {}
	
	var _items_quantities: PBField
	func get_items_quantities() -> Array:
		return _items_quantities.value
	func clear_items_quantities() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_items_quantities.value = []
	func add_items_quantities() -> ItemQuantity:
		var element = ItemQuantity.new()
		_items_quantities.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ChopShrubRequest:
	func _init():
		var service
		
		_shrub_id = PBField.new("shrub_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = _shrub_id
		data[_shrub_id.tag] = service
		
	var data = {}
	
	var _shrub_id: PBField
	func get_shrub_id() -> int:
		return _shrub_id.value
	func clear_shrub_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_shrub_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_shrub_id(value : int) -> void:
		_shrub_id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ChopShrubResponse:
	func _init():
		var service
		
		_shrub_id = PBField.new("shrub_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = _shrub_id
		data[_shrub_id.tag] = service
		
		_response = PBField.new("response", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _response
		service.func_ref = Callable(self, "new_response")
		data[_response.tag] = service
		
	var data = {}
	
	var _shrub_id: PBField
	func get_shrub_id() -> int:
		return _shrub_id.value
	func clear_shrub_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_shrub_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_shrub_id(value : int) -> void:
		_shrub_id.value = value
	
	var _response: PBField
	func get_response() -> Response:
		return _response.value
	func clear_response() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_response() -> Response:
		_response.value = Response.new()
		return _response.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class XpReward:
	func _init():
		var service
		
		_skill = PBField.new("skill", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = _skill
		data[_skill.tag] = service
		
		_xp = PBField.new("xp", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = _xp
		data[_xp.tag] = service
		
	var data = {}
	
	var _skill: PBField
	func get_skill() -> int:
		return _skill.value
	func clear_skill() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_skill.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_skill(value : int) -> void:
		_skill.value = value
	
	var _xp: PBField
	func get_xp() -> int:
		return _xp.value
	func clear_xp() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_xp(value : int) -> void:
		_xp.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class SkillsXp:
	func _init():
		var service
		
		_xp_rewards = PBField.new("xp_rewards", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 1, true, [])
		service = PBServiceField.new()
		service.field = _xp_rewards
		service.func_ref = Callable(self, "add_xp_rewards")
		data[_xp_rewards.tag] = service
		
	var data = {}
	
	var _xp_rewards: PBField
	func get_xp_rewards() -> Array:
		return _xp_rewards.value
	func clear_xp_rewards() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_xp_rewards.value = []
	func add_xp_rewards() -> XpReward:
		var element = XpReward.new()
		_xp_rewards.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class Packet:
	func _init():
		var service
		
		_sender_id = PBField.new("sender_id", PB_DATA_TYPE.UINT32, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32])
		service = PBServiceField.new()
		service.field = _sender_id
		data[_sender_id.tag] = service
		
		_client_id = PBField.new("client_id", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _client_id
		service.func_ref = Callable(self, "new_client_id")
		data[_client_id.tag] = service
		
		_login_request = PBField.new("login_request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _login_request
		service.func_ref = Callable(self, "new_login_request")
		data[_login_request.tag] = service
		
		_login_response = PBField.new("login_response", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _login_response
		service.func_ref = Callable(self, "new_login_response")
		data[_login_response.tag] = service
		
		_register_request = PBField.new("register_request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _register_request
		service.func_ref = Callable(self, "new_register_request")
		data[_register_request.tag] = service
		
		_register_response = PBField.new("register_response", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _register_response
		service.func_ref = Callable(self, "new_register_response")
		data[_register_response.tag] = service
		
		_logout = PBField.new("logout", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _logout
		service.func_ref = Callable(self, "new_logout")
		data[_logout.tag] = service
		
		_chat = PBField.new("chat", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _chat
		service.func_ref = Callable(self, "new_chat")
		data[_chat.tag] = service
		
		_yell = PBField.new("yell", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _yell
		service.func_ref = Callable(self, "new_yell")
		data[_yell.tag] = service
		
		_actor = PBField.new("actor", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 10, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _actor
		service.func_ref = Callable(self, "new_actor")
		data[_actor.tag] = service
		
		_actor_move = PBField.new("actor_move", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 11, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _actor_move
		service.func_ref = Callable(self, "new_actor_move")
		data[_actor_move.tag] = service
		
		_motd = PBField.new("motd", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 12, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _motd
		service.func_ref = Callable(self, "new_motd")
		data[_motd.tag] = service
		
		_disconnect = PBField.new("disconnect", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 13, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _disconnect
		service.func_ref = Callable(self, "new_disconnect")
		data[_disconnect.tag] = service
		
		_admin_login_granted = PBField.new("admin_login_granted", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 14, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _admin_login_granted
		service.func_ref = Callable(self, "new_admin_login_granted")
		data[_admin_login_granted.tag] = service
		
		_sql_query = PBField.new("sql_query", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 15, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _sql_query
		service.func_ref = Callable(self, "new_sql_query")
		data[_sql_query.tag] = service
		
		_sql_response = PBField.new("sql_response", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 16, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _sql_response
		service.func_ref = Callable(self, "new_sql_response")
		data[_sql_response.tag] = service
		
		_level_upload = PBField.new("level_upload", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 17, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _level_upload
		service.func_ref = Callable(self, "new_level_upload")
		data[_level_upload.tag] = service
		
		_level_upload_response = PBField.new("level_upload_response", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 18, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _level_upload_response
		service.func_ref = Callable(self, "new_level_upload_response")
		data[_level_upload_response.tag] = service
		
		_level_download = PBField.new("level_download", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 19, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _level_download
		service.func_ref = Callable(self, "new_level_download")
		data[_level_download.tag] = service
		
		_admin_join_game_request = PBField.new("admin_join_game_request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 20, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _admin_join_game_request
		service.func_ref = Callable(self, "new_admin_join_game_request")
		data[_admin_join_game_request.tag] = service
		
		_admin_join_game_response = PBField.new("admin_join_game_response", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 21, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _admin_join_game_response
		service.func_ref = Callable(self, "new_admin_join_game_response")
		data[_admin_join_game_response.tag] = service
		
		_server_message = PBField.new("server_message", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 22, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _server_message
		service.func_ref = Callable(self, "new_server_message")
		data[_server_message.tag] = service
		
		_pickup_ground_item_request = PBField.new("pickup_ground_item_request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 23, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _pickup_ground_item_request
		service.func_ref = Callable(self, "new_pickup_ground_item_request")
		data[_pickup_ground_item_request.tag] = service
		
		_pickup_ground_item_response = PBField.new("pickup_ground_item_response", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 24, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _pickup_ground_item_response
		service.func_ref = Callable(self, "new_pickup_ground_item_response")
		data[_pickup_ground_item_response.tag] = service
		
		_shrub = PBField.new("shrub", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 25, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _shrub
		service.func_ref = Callable(self, "new_shrub")
		data[_shrub.tag] = service
		
		_door = PBField.new("door", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 26, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _door
		service.func_ref = Callable(self, "new_door")
		data[_door.tag] = service
		
		_Item = PBField.new("Item", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 27, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _Item
		service.func_ref = Callable(self, "new_Item")
		data[_Item.tag] = service
		
		_ground_item = PBField.new("ground_item", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 28, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _ground_item
		service.func_ref = Callable(self, "new_ground_item")
		data[_ground_item.tag] = service
		
		_actor_inventory = PBField.new("actor_inventory", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 29, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _actor_inventory
		service.func_ref = Callable(self, "new_actor_inventory")
		data[_actor_inventory.tag] = service
		
		_drop_item_request = PBField.new("drop_item_request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 30, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _drop_item_request
		service.func_ref = Callable(self, "new_drop_item_request")
		data[_drop_item_request.tag] = service
		
		_drop_item_response = PBField.new("drop_item_response", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 31, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _drop_item_response
		service.func_ref = Callable(self, "new_drop_item_response")
		data[_drop_item_response.tag] = service
		
		_chop_shrub_request = PBField.new("chop_shrub_request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 32, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _chop_shrub_request
		service.func_ref = Callable(self, "new_chop_shrub_request")
		data[_chop_shrub_request.tag] = service
		
		_chop_shrub_response = PBField.new("chop_shrub_response", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 33, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _chop_shrub_response
		service.func_ref = Callable(self, "new_chop_shrub_response")
		data[_chop_shrub_response.tag] = service
		
		_item_quantity = PBField.new("item_quantity", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 34, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _item_quantity
		service.func_ref = Callable(self, "new_item_quantity")
		data[_item_quantity.tag] = service
		
		_xp_reward = PBField.new("xp_reward", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 35, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _xp_reward
		service.func_ref = Callable(self, "new_xp_reward")
		data[_xp_reward.tag] = service
		
		_skills_xp = PBField.new("skills_xp", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 36, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = _skills_xp
		service.func_ref = Callable(self, "new_skills_xp")
		data[_skills_xp.tag] = service
		
	var data = {}
	
	var _sender_id: PBField
	func get_sender_id() -> int:
		return _sender_id.value
	func clear_sender_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		_sender_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT32]
	func set_sender_id(value : int) -> void:
		_sender_id.value = value
	
	var _client_id: PBField
	func has_client_id() -> bool:
		return data[2].state == PB_SERVICE_STATE.FILLED
	func get_client_id() -> ClientId:
		return _client_id.value
	func clear_client_id() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_client_id() -> ClientId:
		data[2].state = PB_SERVICE_STATE.FILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_client_id.value = ClientId.new()
		return _client_id.value
	
	var _login_request: PBField
	func has_login_request() -> bool:
		return data[3].state == PB_SERVICE_STATE.FILLED
	func get_login_request() -> LoginRequest:
		return _login_request.value
	func clear_login_request() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_login_request() -> LoginRequest:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		data[3].state = PB_SERVICE_STATE.FILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = LoginRequest.new()
		return _login_request.value
	
	var _login_response: PBField
	func has_login_response() -> bool:
		return data[4].state == PB_SERVICE_STATE.FILLED
	func get_login_response() -> LoginResponse:
		return _login_response.value
	func clear_login_response() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_login_response() -> LoginResponse:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		data[4].state = PB_SERVICE_STATE.FILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = LoginResponse.new()
		return _login_response.value
	
	var _register_request: PBField
	func has_register_request() -> bool:
		return data[5].state == PB_SERVICE_STATE.FILLED
	func get_register_request() -> RegisterRequest:
		return _register_request.value
	func clear_register_request() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_register_request() -> RegisterRequest:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		data[5].state = PB_SERVICE_STATE.FILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = RegisterRequest.new()
		return _register_request.value
	
	var _register_response: PBField
	func has_register_response() -> bool:
		return data[6].state == PB_SERVICE_STATE.FILLED
	func get_register_response() -> RegisterResponse:
		return _register_response.value
	func clear_register_response() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_register_response() -> RegisterResponse:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		data[6].state = PB_SERVICE_STATE.FILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = RegisterResponse.new()
		return _register_response.value
	
	var _logout: PBField
	func has_logout() -> bool:
		return data[7].state == PB_SERVICE_STATE.FILLED
	func get_logout() -> Logout:
		return _logout.value
	func clear_logout() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_logout() -> Logout:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		data[7].state = PB_SERVICE_STATE.FILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = Logout.new()
		return _logout.value
	
	var _chat: PBField
	func has_chat() -> bool:
		return data[8].state == PB_SERVICE_STATE.FILLED
	func get_chat() -> Chat:
		return _chat.value
	func clear_chat() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_chat() -> Chat:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		data[8].state = PB_SERVICE_STATE.FILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = Chat.new()
		return _chat.value
	
	var _yell: PBField
	func has_yell() -> bool:
		return data[9].state == PB_SERVICE_STATE.FILLED
	func get_yell() -> Yell:
		return _yell.value
	func clear_yell() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_yell() -> Yell:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		data[9].state = PB_SERVICE_STATE.FILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = Yell.new()
		return _yell.value
	
	var _actor: PBField
	func has_actor() -> bool:
		return data[10].state == PB_SERVICE_STATE.FILLED
	func get_actor() -> Actor:
		return _actor.value
	func clear_actor() -> void:
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_actor() -> Actor:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		data[10].state = PB_SERVICE_STATE.FILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = Actor.new()
		return _actor.value
	
	var _actor_move: PBField
	func has_actor_move() -> bool:
		return data[11].state == PB_SERVICE_STATE.FILLED
	func get_actor_move() -> ActorMove:
		return _actor_move.value
	func clear_actor_move() -> void:
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_actor_move() -> ActorMove:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		data[11].state = PB_SERVICE_STATE.FILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = ActorMove.new()
		return _actor_move.value
	
	var _motd: PBField
	func has_motd() -> bool:
		return data[12].state == PB_SERVICE_STATE.FILLED
	func get_motd() -> Motd:
		return _motd.value
	func clear_motd() -> void:
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_motd() -> Motd:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		data[12].state = PB_SERVICE_STATE.FILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = Motd.new()
		return _motd.value
	
	var _disconnect: PBField
	func has_disconnect() -> bool:
		return data[13].state == PB_SERVICE_STATE.FILLED
	func get_disconnect() -> Disconnect:
		return _disconnect.value
	func clear_disconnect() -> void:
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_disconnect() -> Disconnect:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		data[13].state = PB_SERVICE_STATE.FILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = Disconnect.new()
		return _disconnect.value
	
	var _admin_login_granted: PBField
	func has_admin_login_granted() -> bool:
		return data[14].state == PB_SERVICE_STATE.FILLED
	func get_admin_login_granted() -> AdminLoginGranted:
		return _admin_login_granted.value
	func clear_admin_login_granted() -> void:
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_admin_login_granted() -> AdminLoginGranted:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		data[14].state = PB_SERVICE_STATE.FILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = AdminLoginGranted.new()
		return _admin_login_granted.value
	
	var _sql_query: PBField
	func has_sql_query() -> bool:
		return data[15].state == PB_SERVICE_STATE.FILLED
	func get_sql_query() -> SqlQuery:
		return _sql_query.value
	func clear_sql_query() -> void:
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_sql_query() -> SqlQuery:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		data[15].state = PB_SERVICE_STATE.FILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = SqlQuery.new()
		return _sql_query.value
	
	var _sql_response: PBField
	func has_sql_response() -> bool:
		return data[16].state == PB_SERVICE_STATE.FILLED
	func get_sql_response() -> SqlResponse:
		return _sql_response.value
	func clear_sql_response() -> void:
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_sql_response() -> SqlResponse:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		data[16].state = PB_SERVICE_STATE.FILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = SqlResponse.new()
		return _sql_response.value
	
	var _level_upload: PBField
	func has_level_upload() -> bool:
		return data[17].state == PB_SERVICE_STATE.FILLED
	func get_level_upload() -> LevelUpload:
		return _level_upload.value
	func clear_level_upload() -> void:
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_level_upload() -> LevelUpload:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		data[17].state = PB_SERVICE_STATE.FILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = LevelUpload.new()
		return _level_upload.value
	
	var _level_upload_response: PBField
	func has_level_upload_response() -> bool:
		return data[18].state == PB_SERVICE_STATE.FILLED
	func get_level_upload_response() -> LevelUploadResponse:
		return _level_upload_response.value
	func clear_level_upload_response() -> void:
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_level_upload_response() -> LevelUploadResponse:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		data[18].state = PB_SERVICE_STATE.FILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = LevelUploadResponse.new()
		return _level_upload_response.value
	
	var _level_download: PBField
	func has_level_download() -> bool:
		return data[19].state == PB_SERVICE_STATE.FILLED
	func get_level_download() -> LevelDownload:
		return _level_download.value
	func clear_level_download() -> void:
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_level_download() -> LevelDownload:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		data[19].state = PB_SERVICE_STATE.FILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = LevelDownload.new()
		return _level_download.value
	
	var _admin_join_game_request: PBField
	func has_admin_join_game_request() -> bool:
		return data[20].state == PB_SERVICE_STATE.FILLED
	func get_admin_join_game_request() -> AdminJoinGameRequest:
		return _admin_join_game_request.value
	func clear_admin_join_game_request() -> void:
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_admin_join_game_request() -> AdminJoinGameRequest:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		data[20].state = PB_SERVICE_STATE.FILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = AdminJoinGameRequest.new()
		return _admin_join_game_request.value
	
	var _admin_join_game_response: PBField
	func has_admin_join_game_response() -> bool:
		return data[21].state == PB_SERVICE_STATE.FILLED
	func get_admin_join_game_response() -> AdminJoinGameResponse:
		return _admin_join_game_response.value
	func clear_admin_join_game_response() -> void:
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_admin_join_game_response() -> AdminJoinGameResponse:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		data[21].state = PB_SERVICE_STATE.FILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = AdminJoinGameResponse.new()
		return _admin_join_game_response.value
	
	var _server_message: PBField
	func has_server_message() -> bool:
		return data[22].state == PB_SERVICE_STATE.FILLED
	func get_server_message() -> ServerMessage:
		return _server_message.value
	func clear_server_message() -> void:
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_server_message() -> ServerMessage:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		data[22].state = PB_SERVICE_STATE.FILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = ServerMessage.new()
		return _server_message.value
	
	var _pickup_ground_item_request: PBField
	func has_pickup_ground_item_request() -> bool:
		return data[23].state == PB_SERVICE_STATE.FILLED
	func get_pickup_ground_item_request() -> PickupGroundItemRequest:
		return _pickup_ground_item_request.value
	func clear_pickup_ground_item_request() -> void:
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_pickup_ground_item_request() -> PickupGroundItemRequest:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		data[23].state = PB_SERVICE_STATE.FILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = PickupGroundItemRequest.new()
		return _pickup_ground_item_request.value
	
	var _pickup_ground_item_response: PBField
	func has_pickup_ground_item_response() -> bool:
		return data[24].state == PB_SERVICE_STATE.FILLED
	func get_pickup_ground_item_response() -> PickupGroundItemResponse:
		return _pickup_ground_item_response.value
	func clear_pickup_ground_item_response() -> void:
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_pickup_ground_item_response() -> PickupGroundItemResponse:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		data[24].state = PB_SERVICE_STATE.FILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = PickupGroundItemResponse.new()
		return _pickup_ground_item_response.value
	
	var _shrub: PBField
	func has_shrub() -> bool:
		return data[25].state == PB_SERVICE_STATE.FILLED
	func get_shrub() -> Shrub:
		return _shrub.value
	func clear_shrub() -> void:
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_shrub() -> Shrub:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		data[25].state = PB_SERVICE_STATE.FILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = Shrub.new()
		return _shrub.value
	
	var _door: PBField
	func has_door() -> bool:
		return data[26].state == PB_SERVICE_STATE.FILLED
	func get_door() -> Door:
		return _door.value
	func clear_door() -> void:
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_door() -> Door:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		data[26].state = PB_SERVICE_STATE.FILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_door.value = Door.new()
		return _door.value
	
	var _Item: PBField
	func has_Item() -> bool:
		return data[27].state == PB_SERVICE_STATE.FILLED
	func get_Item() -> Item:
		return _Item.value
	func clear_Item() -> void:
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_Item() -> Item:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		data[27].state = PB_SERVICE_STATE.FILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = Item.new()
		return _Item.value
	
	var _ground_item: PBField
	func has_ground_item() -> bool:
		return data[28].state == PB_SERVICE_STATE.FILLED
	func get_ground_item() -> GroundItem:
		return _ground_item.value
	func clear_ground_item() -> void:
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_ground_item() -> GroundItem:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		data[28].state = PB_SERVICE_STATE.FILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = GroundItem.new()
		return _ground_item.value
	
	var _actor_inventory: PBField
	func has_actor_inventory() -> bool:
		return data[29].state == PB_SERVICE_STATE.FILLED
	func get_actor_inventory() -> ActorInventory:
		return _actor_inventory.value
	func clear_actor_inventory() -> void:
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_actor_inventory() -> ActorInventory:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		data[29].state = PB_SERVICE_STATE.FILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = ActorInventory.new()
		return _actor_inventory.value
	
	var _drop_item_request: PBField
	func has_drop_item_request() -> bool:
		return data[30].state == PB_SERVICE_STATE.FILLED
	func get_drop_item_request() -> DropItemRequest:
		return _drop_item_request.value
	func clear_drop_item_request() -> void:
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_drop_item_request() -> DropItemRequest:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		data[30].state = PB_SERVICE_STATE.FILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DropItemRequest.new()
		return _drop_item_request.value
	
	var _drop_item_response: PBField
	func has_drop_item_response() -> bool:
		return data[31].state == PB_SERVICE_STATE.FILLED
	func get_drop_item_response() -> DropItemResponse:
		return _drop_item_response.value
	func clear_drop_item_response() -> void:
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_drop_item_response() -> DropItemResponse:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		data[31].state = PB_SERVICE_STATE.FILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DropItemResponse.new()
		return _drop_item_response.value
	
	var _chop_shrub_request: PBField
	func has_chop_shrub_request() -> bool:
		return data[32].state == PB_SERVICE_STATE.FILLED
	func get_chop_shrub_request() -> ChopShrubRequest:
		return _chop_shrub_request.value
	func clear_chop_shrub_request() -> void:
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_chop_shrub_request() -> ChopShrubRequest:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		data[32].state = PB_SERVICE_STATE.FILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = ChopShrubRequest.new()
		return _chop_shrub_request.value
	
	var _chop_shrub_response: PBField
	func has_chop_shrub_response() -> bool:
		return data[33].state == PB_SERVICE_STATE.FILLED
	func get_chop_shrub_response() -> ChopShrubResponse:
		return _chop_shrub_response.value
	func clear_chop_shrub_response() -> void:
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_chop_shrub_response() -> ChopShrubResponse:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		data[33].state = PB_SERVICE_STATE.FILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = ChopShrubResponse.new()
		return _chop_shrub_response.value
	
	var _item_quantity: PBField
	func has_item_quantity() -> bool:
		return data[34].state == PB_SERVICE_STATE.FILLED
	func get_item_quantity() -> ItemQuantity:
		return _item_quantity.value
	func clear_item_quantity() -> void:
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_item_quantity() -> ItemQuantity:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		data[34].state = PB_SERVICE_STATE.FILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = ItemQuantity.new()
		return _item_quantity.value
	
	var _xp_reward: PBField
	func has_xp_reward() -> bool:
		return data[35].state == PB_SERVICE_STATE.FILLED
	func get_xp_reward() -> XpReward:
		return _xp_reward.value
	func clear_xp_reward() -> void:
		data[35].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_xp_reward() -> XpReward:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		data[35].state = PB_SERVICE_STATE.FILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = XpReward.new()
		return _xp_reward.value
	
	var _skills_xp: PBField
	func has_skills_xp() -> bool:
		return data[36].state == PB_SERVICE_STATE.FILLED
	func get_skills_xp() -> SkillsXp:
		return _skills_xp.value
	func clear_skills_xp() -> void:
		data[36].state = PB_SERVICE_STATE.UNFILLED
		_skills_xp.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_skills_xp() -> SkillsXp:
		_client_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		_login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		_login_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		_register_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		_register_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		_logout.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		_chat.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		_yell.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[9].state = PB_SERVICE_STATE.UNFILLED
		_actor.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[10].state = PB_SERVICE_STATE.UNFILLED
		_actor_move.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[11].state = PB_SERVICE_STATE.UNFILLED
		_motd.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[12].state = PB_SERVICE_STATE.UNFILLED
		_disconnect.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[13].state = PB_SERVICE_STATE.UNFILLED
		_admin_login_granted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[14].state = PB_SERVICE_STATE.UNFILLED
		_sql_query.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[15].state = PB_SERVICE_STATE.UNFILLED
		_sql_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[16].state = PB_SERVICE_STATE.UNFILLED
		_level_upload.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[17].state = PB_SERVICE_STATE.UNFILLED
		_level_upload_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[18].state = PB_SERVICE_STATE.UNFILLED
		_level_download.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[19].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[20].state = PB_SERVICE_STATE.UNFILLED
		_admin_join_game_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[21].state = PB_SERVICE_STATE.UNFILLED
		_server_message.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[22].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[23].state = PB_SERVICE_STATE.UNFILLED
		_pickup_ground_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[24].state = PB_SERVICE_STATE.UNFILLED
		_shrub.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[25].state = PB_SERVICE_STATE.UNFILLED
		_door.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[26].state = PB_SERVICE_STATE.UNFILLED
		_Item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[27].state = PB_SERVICE_STATE.UNFILLED
		_ground_item.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[28].state = PB_SERVICE_STATE.UNFILLED
		_actor_inventory.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[29].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[30].state = PB_SERVICE_STATE.UNFILLED
		_drop_item_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[31].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[32].state = PB_SERVICE_STATE.UNFILLED
		_chop_shrub_response.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[33].state = PB_SERVICE_STATE.UNFILLED
		_item_quantity.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[34].state = PB_SERVICE_STATE.UNFILLED
		_xp_reward.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[35].state = PB_SERVICE_STATE.UNFILLED
		data[36].state = PB_SERVICE_STATE.FILLED
		_skills_xp.value = SkillsXp.new()
		return _skills_xp.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
################ USER DATA END #################
