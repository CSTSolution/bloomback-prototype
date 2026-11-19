// BloomBack Pro: bought once (a non-consumable on both stores) and tied to the account, confirmed by our server before
// the app tells the store it is done, so a purchase the server has not seen keeps coming back until it has.
// "Restore purchases" finds it again on a new phone. (Pattern from Foreman's Toolbox Talk's crew pass.)
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'account.dart';
import 'api.dart';

const kProProductId = 'com.cst.bloomback.pro';

enum ProState { looking, forSale, unavailable, working, owned }

class ProStore extends ChangeNotifier {
  ProStore(this.account, [this._iap]);

  final Account account;
  InAppPurchase? _iap;
  StreamSubscription<List<PurchaseDetails>>? _events;

  ProState state = ProState.looking;
  ProductDetails? product;
  String? note;

  bool get _owned => account.standing.pro && account.standing.lifetime;

  /// Price as the store shows it, or null before the store answers.
  String? get price => product?.price;

  Future<void> start() async {
    if (_owned) state = ProState.owned;
    if (kIsWeb) return _set(ProState.unavailable);
    try {
      final iap = _iap ??= InAppPurchase.instance;
      _events ??= iap.purchaseStream.listen(_onEvents, onError: (_) {});
      if (!await iap.isAvailable()) return _set(ProState.unavailable);
      final found = await iap.queryProductDetails({kProProductId});
      product = found.productDetails.where((p) => p.id == kProProductId).firstOrNull;
      _set(_owned ? ProState.owned : (product == null ? ProState.unavailable : ProState.forSale));
    } catch (_) {
      _set(ProState.unavailable);
    }
  }

  Future<void> buy() async {
    final iap = _iap;
    final p = product;
    if (iap == null || p == null || state == ProState.working) return;
    _set(ProState.working, words: null);
    try {
      final started = await iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
      if (!started) _set(ProState.forSale, words: 'The store did not open the purchase.');
    } catch (_) {
      _set(ProState.forSale, words: 'The store did not open the purchase.');
    }
  }

  Future<void> restore() async {
    final iap = _iap;
    if (iap == null) return;
    _set(_owned ? ProState.owned : ProState.working, words: 'Looking for BloomBack Pro…');
    try {
      await iap.restorePurchases();
      await Future<void>.delayed(const Duration(seconds: 4));
      if (state == ProState.working) _set(ProState.forSale, words: 'No BloomBack Pro purchase was found for this store account.');
    } catch (_) {
      _set(ProState.forSale, words: 'The store did not answer. Try again in a minute.');
    }
  }

  void _set(ProState s, {String? words = ''}) {
    state = s;
    if (words != '') note = words;
    notifyListeners();
  }

  Future<void> _onEvents(List<PurchaseDetails> events) async {
    for (final e in events) {
      switch (e.status) {
        case PurchaseStatus.pending:
          _set(ProState.working, words: 'Waiting for the store…');
        case PurchaseStatus.canceled:
          await _complete(e);
          _set(ProState.forSale, words: null);
        case PurchaseStatus.error:
          await _complete(e);
          _set(ProState.forSale, words: 'The purchase did not go through. Nothing was charged.');
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          await _confirm(e);
      }
    }
  }

  Future<void> _confirm(PurchaseDetails e) async {
    if (e.productID != kProProductId) return;
    if (!account.signedIn) {
      // Pro belongs to an account; leave the purchase with the store until the person signs in.
      _set(ProState.forSale, words: 'Sign in first, then tap "Restore purchases" to add Pro to your account.');
      return;
    }
    final proof = defaultTargetPlatform == TargetPlatform.android
        ? {'store': 'google', 'product': e.productID, 'token': e.verificationData.serverVerificationData}
        : {'store': 'apple', 'signed': e.verificationData.serverVerificationData};
    try {
      final result = await account.claimPurchase(proof);
      await _complete(e);
      _set(ProState.owned, words: result == 'added' ? 'BloomBack Pro is on. Thank you!' : 'BloomBack Pro found.');
    } on ApiProblem catch (p) {
      // a proof the server refused will never pass: finish it so it stops returning. Offline: leave it for next time.
      if (p.problem == 'not_paid' || p.problem == 'too_many_accounts') await _complete(e);
      _set(ProState.forSale, words: p.words);
    }
  }

  Future<void> _complete(PurchaseDetails e) async {
    if (e.pendingCompletePurchase) await _iap?.completePurchase(e);
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }
}
