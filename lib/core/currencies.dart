class Currency {
  final String code;
  final String symbol;
  final String name;
  final int decimals;
  const Currency(this.code, this.symbol, this.name, [this.decimals = 2]);
}

const currencies = <Currency>[
  Currency('USD', '\$', 'US Dollar'),
  Currency('EUR', '€', 'Euro'),
  Currency('GBP', '£', 'British Pound'),
  Currency('NPR', 'Rs', 'Nepalese Rupee'),
  Currency('INR', '₹', 'Indian Rupee'),
  Currency('JPY', '¥', 'Japanese Yen', 0),
  Currency('CNY', '¥', 'Chinese Yuan'),
  Currency('AUD', 'A\$', 'Australian Dollar'),
  Currency('CAD', 'C\$', 'Canadian Dollar'),
  Currency('CHF', 'CHF', 'Swiss Franc'),
  Currency('AED', 'AED', 'UAE Dirham'),
  Currency('SAR', 'SAR', 'Saudi Riyal'),
  Currency('QAR', 'QAR', 'Qatari Riyal'),
  Currency('THB', '฿', 'Thai Baht'),
  Currency('SGD', 'S\$', 'Singapore Dollar'),
  Currency('MYR', 'RM', 'Malaysian Ringgit'),
  Currency('IDR', 'Rp', 'Indonesian Rupiah', 0),
  Currency('VND', '₫', 'Vietnamese Dong', 0),
  Currency('PHP', '₱', 'Philippine Peso'),
  Currency('KRW', '₩', 'South Korean Won', 0),
  Currency('HKD', 'HK\$', 'Hong Kong Dollar'),
  Currency('TWD', 'NT\$', 'New Taiwan Dollar'),
  Currency('LKR', 'Rs', 'Sri Lankan Rupee'),
  Currency('BDT', '৳', 'Bangladeshi Taka'),
  Currency('PKR', 'Rs', 'Pakistani Rupee'),
  Currency('MVR', 'Rf', 'Maldivian Rufiyaa'),
  Currency('BTN', 'Nu', 'Bhutanese Ngultrum'),
  Currency('NZD', 'NZ\$', 'New Zealand Dollar'),
  Currency('SEK', 'kr', 'Swedish Krona'),
  Currency('NOK', 'kr', 'Norwegian Krone'),
  Currency('DKK', 'kr', 'Danish Krone'),
  Currency('PLN', 'zł', 'Polish Złoty'),
  Currency('CZK', 'Kč', 'Czech Koruna'),
  Currency('HUF', 'Ft', 'Hungarian Forint'),
  Currency('TRY', '₺', 'Turkish Lira'),
  Currency('RUB', '₽', 'Russian Ruble'),
  Currency('ZAR', 'R', 'South African Rand'),
  Currency('EGP', 'E£', 'Egyptian Pound'),
  Currency('KES', 'KSh', 'Kenyan Shilling'),
  Currency('NGN', '₦', 'Nigerian Naira'),
  Currency('MAD', 'MAD', 'Moroccan Dirham'),
  Currency('BRL', 'R\$', 'Brazilian Real'),
  Currency('MXN', 'MX\$', 'Mexican Peso'),
  Currency('ARS', 'AR\$', 'Argentine Peso'),
  Currency('CLP', 'CLP\$', 'Chilean Peso', 0),
  Currency('COP', 'COL\$', 'Colombian Peso', 0),
  Currency('PEN', 'S/', 'Peruvian Sol'),
  Currency('ILS', '₪', 'Israeli Shekel'),
];

Currency currencyFor(String code) =>
    currencies.firstWhere((c) => c.code == code, orElse: () => currencies.first);
