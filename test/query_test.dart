// ignore_for_file: avoid_print
import 'package:supabase_flutter/supabase_flutter.dart';


Future<void> main() async {
  print('Initializing Supabase...');
  await Supabase.initialize(
    url: 'https://ebwubdwcksqihxiycdna.supabase.co',
    anonKey: 'sb_publishable_0SXIMX7YlPmkey6HoQ_KYg_L76gdA_X',
  );
  final client = Supabase.instance.client;

  try {
    print('Querying products with joins...');
    final data = await client
        .from('products')
        .select('*, categories(id, name), supplier_products(*, suppliers(*))');
    print('Products with joins response: $data');
  } catch (e) {
    print('Products with joins error: $e');
  }

  try {
    print('Querying products with user_id filter...');
    final data = await client
        .from('products')
        .select()
        .eq('user_id', '00000000-0000-0000-0000-000000000000');
    print('Products with user_id response: $data');
  } catch (e) {
    print('Products with user_id error: $e');
  }
}
