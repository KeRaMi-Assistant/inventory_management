class Supplier {
  final String id;
  final String name;
  final String? contactName;
  final String? email;
  final String? phone;
  final String? website;
  final String? note;
  final bool active;

  const Supplier({
    required this.id,
    required this.name,
    this.contactName,
    this.email,
    this.phone,
    this.website,
    this.note,
    this.active = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'contactName': contactName,
        'email': email,
        'phone': phone,
        'website': website,
        'note': note,
        'active': active,
      };

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: json['id'] as String,
        name: json['name'] as String,
        contactName: json['contactName'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        website: json['website'] as String?,
        note: json['note'] as String?,
        active: json['active'] as bool? ?? true,
      );

  Map<String, dynamic> toSupabaseInsert() => {
        if (id.isNotEmpty) 'id': id,
        'name': name,
        'contact_name': contactName,
        'email': email,
        'phone': phone,
        'website': website,
        'note': note,
        'active': active,
      };

  factory Supplier.fromSupabase(Map<String, dynamic> row) => Supplier(
        id: row['id'] as String,
        name: row['name'] as String,
        contactName: row['contact_name'] as String?,
        email: row['email'] as String?,
        phone: row['phone'] as String?,
        website: row['website'] as String?,
        note: row['note'] as String?,
        active: row['active'] as bool? ?? true,
      );

  Supplier copyWith({
    String? id,
    String? name,
    Object? contactName = _sentinel,
    Object? email = _sentinel,
    Object? phone = _sentinel,
    Object? website = _sentinel,
    Object? note = _sentinel,
    bool? active,
  }) =>
      Supplier(
        id: id ?? this.id,
        name: name ?? this.name,
        contactName: contactName == _sentinel
            ? this.contactName
            : contactName as String?,
        email: email == _sentinel ? this.email : email as String?,
        phone: phone == _sentinel ? this.phone : phone as String?,
        website: website == _sentinel ? this.website : website as String?,
        note: note == _sentinel ? this.note : note as String?,
        active: active ?? this.active,
      );
}

const Object _sentinel = Object();
