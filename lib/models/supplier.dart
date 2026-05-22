class Supplier {
  final String id;
  final String name;
  final String? contactName;
  final String? email;
  final String? phone;
  final String? website;
  final String? note;
  final bool active;

  // Extended kreditor fields (B1 migration)
  final String? addressStreet;
  final String? addressZip;
  final String? addressCity;
  final String? addressCountry;
  final String? vatId;
  final String? customerNumber;
  final int? paymentTermsDays;
  final int? leadTimeDays;
  final double? minOrderValue;

  const Supplier({
    required this.id,
    required this.name,
    this.contactName,
    this.email,
    this.phone,
    this.website,
    this.note,
    this.active = true,
    this.addressStreet,
    this.addressZip,
    this.addressCity,
    this.addressCountry,
    this.vatId,
    this.customerNumber,
    this.paymentTermsDays,
    this.leadTimeDays,
    this.minOrderValue,
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
        'addressStreet': addressStreet,
        'addressZip': addressZip,
        'addressCity': addressCity,
        'addressCountry': addressCountry,
        'vatId': vatId,
        'customerNumber': customerNumber,
        'paymentTermsDays': paymentTermsDays,
        'leadTimeDays': leadTimeDays,
        'minOrderValue': minOrderValue,
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
        addressStreet: json['addressStreet'] as String?,
        addressZip: json['addressZip'] as String?,
        addressCity: json['addressCity'] as String?,
        addressCountry: json['addressCountry'] as String?,
        vatId: json['vatId'] as String?,
        customerNumber: json['customerNumber'] as String?,
        paymentTermsDays: json['paymentTermsDays'] as int?,
        leadTimeDays: json['leadTimeDays'] as int?,
        minOrderValue: (json['minOrderValue'] as num?)?.toDouble(),
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
        'address_street': addressStreet,
        'address_zip': addressZip,
        'address_city': addressCity,
        'address_country': addressCountry,
        'vat_id': vatId,
        'customer_number': customerNumber,
        'payment_terms_days': paymentTermsDays,
        'lead_time_days': leadTimeDays,
        'min_order_value': minOrderValue,
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
        addressStreet: row['address_street'] as String?,
        addressZip: row['address_zip'] as String?,
        addressCity: row['address_city'] as String?,
        addressCountry: row['address_country'] as String?,
        vatId: row['vat_id'] as String?,
        customerNumber: row['customer_number'] as String?,
        paymentTermsDays: (row['payment_terms_days'] as num?)?.toInt(),
        leadTimeDays: (row['lead_time_days'] as num?)?.toInt(),
        minOrderValue: (row['min_order_value'] as num?)?.toDouble(),
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
    Object? addressStreet = _sentinel,
    Object? addressZip = _sentinel,
    Object? addressCity = _sentinel,
    Object? addressCountry = _sentinel,
    Object? vatId = _sentinel,
    Object? customerNumber = _sentinel,
    Object? paymentTermsDays = _sentinel,
    Object? leadTimeDays = _sentinel,
    Object? minOrderValue = _sentinel,
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
        addressStreet: addressStreet == _sentinel
            ? this.addressStreet
            : addressStreet as String?,
        addressZip: addressZip == _sentinel
            ? this.addressZip
            : addressZip as String?,
        addressCity: addressCity == _sentinel
            ? this.addressCity
            : addressCity as String?,
        addressCountry: addressCountry == _sentinel
            ? this.addressCountry
            : addressCountry as String?,
        vatId: vatId == _sentinel ? this.vatId : vatId as String?,
        customerNumber: customerNumber == _sentinel
            ? this.customerNumber
            : customerNumber as String?,
        paymentTermsDays: paymentTermsDays == _sentinel
            ? this.paymentTermsDays
            : paymentTermsDays as int?,
        leadTimeDays: leadTimeDays == _sentinel
            ? this.leadTimeDays
            : leadTimeDays as int?,
        minOrderValue: minOrderValue == _sentinel
            ? this.minOrderValue
            : minOrderValue as double?,
      );
}

const Object _sentinel = Object();
