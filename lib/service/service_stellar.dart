import 'package:maxtoken/model/asset.dart';
import 'package:maxtoken/model/transaction.dart';
import 'package:maxtoken/service/service.dart';
import 'package:stellar/stellar.dart' as stellar;
import 'package:stellar_hd_wallet/stellar_hd_wallet.dart';
import 'package:maxtoken/model/asset.dart';
import 'package:maxtoken/model/account.dart';
import 'package:maxtoken/model/transaction.dart';

/// 恒生服务功能
class StellarService extends Service{

  String _horizon;
  stellar.Server _server;

  StellarService._(String horizon){
    if(horizon == null){
      this._horizon = "https://horizon-testnet.stellar.org";
      stellar.Network.useTestNetwork();
    }else if(horizon.indexOf("testnet") > 0){
      this._horizon =horizon;
      stellar.Network.useTestNetwork();
    }else{
      this._horizon =horizon;
      stellar.Network.usePublicNetwork();
    }
    this._server = new stellar.Server(this._horizon);
  }

  @override
  Future<Account> getBalance(String address) async {
    final kp = stellar.KeyPair.fromAccountId(address);
    final account = await this._server.accounts.account(kp);
    final balances = account.balances;
    List<Asset> assets =List();
    balances.forEach((b){
      String code = null,issuer=null,host=null;
      bool isNative = false;
      if(b.assetCode!=null){
        code = 'XLM';
        host = 'stellar.org';
        isNative = true;
      }else{
        code = b.assetCode;
        issuer = b.assetIssuer.accountId;
      }
      final asset = StellarAsset(code,issuer,host,isNative,b.balance);
      asset.limit = b.limit;
      asset.buyingLiabilities = b.buyingLiabilities;
      asset.sellingLiabilities = b.sellingLiabilities;
      asset.assetType = b.assetType;
      assets.add(asset);
    });
    final result = StellarAccount(address, assets);
    result.sequenceNumber = account.sequenceNumber;
    result.subentryCount = account.subentryCount;
    result.inflationDestination = account.inflationDestination;
    result.thresholds = {
      "low_threshold": account.thresholds.lowThreshold,
      "med_threshold": account.thresholds.medThreshold,
      "high_threshold": account.thresholds.medThreshold,
    };
    result.flags = {
      "auth_required": account.flags.authRequired,
      "auth_revocable": account.flags.authRevocable,
      "auth_immutable": account.flags.authImmutable
    };
    return result;
  }

  @override
  Future<Transaction> getTransactionByHash(String hash) async{
    final tx = await this._server.transactions.transaction(hash);
    StellarTransaction stx =StellarTransaction();
    stx.hash =hash;
    stx.ledger = tx.ledger;
    // stx.memo = tx.memo.
    stx.operationCount = tx.operationCount;
    stx.pagingToken = tx.pagingToken;
    stx.resultMetaXdr = tx.resultMetaXdr;
    stx.resultXdr = tx.resultXdr;
    stx.sourceAccount = tx.sourceAccount.accountId;
    stx.sourceAccountSequence = tx.sourceAccountSequence;
    
    return stx;
  }

  @override
  Future<String> postTransaction(String target,String secret,int gas,Object tx) async {
    // stellar.Transaction tx = stellar.TransactionBuilder();
    final response = await this._server.submitTransaction(tx);
    if(response.success){
      return response.hash;
    }
    return null;
  }
  
  @override
  Future<List<Transaction>> getTransactons(Map params) async{
    var cursor = params['curos'];
    var limit = params['limit'];
    var tx = this._server.transactions;
    if(cursor!=null){
      tx = tx.cursor(cursor);
    }
    limit = limit == null ? 100 : limit;
    tx = tx.limit(limit);
    var order = params['order'];
    order =order == null ? "desc":order;
    var result = await tx.order(order).execute();
    var records = result.records;
    List<Transaction> txs =List();
    for(int i=0,n=records.length; i<n;i++){
      var record =records[i];
      StellarTransaction t = StellarTransaction();
      t.block =record.ledger.toString();
      t.createdAt =record.createdAt;
      t.envelopeXdr =record.envelopeXdr;
      t.feePaid =record.feePaid;
      t.hash =record.hash;
      t.ledger =record.ledger;
      t.memo =record.memo.toXdr().text;
      t.memoType =record.memo.toXdr().discriminant.value;
      t.operationCount =record.operationCount;
      t.pagingToken =record.pagingToken;
      t.resultMetaXdr =record.resultMetaXdr;
      t.resultXdr =record.resultXdr;
      t.sourceAccount =record.sourceAccount.accountId;
      t.sourceAccountSequence =record.sourceAccountSequence;
      txs.add(t);
    }

    return txs;
  }

  stellar.Server get server => this._server;
  
}

/// 恒星地址服务
class StellarAddress extends Address{

  stellar.KeyPair _keypair;

  StellarAddress.fromPublicAddress(String address) : super.fromMnemonic(address);
  StellarAddress.fromSecret(String secret) : super.fromMnemonic(secret){
    //根据私钥生成公钥
    this._keypair = stellar.KeyPair.fromSecretSeed(secret);
    this.address = this._keypair.accountId;
  }
  StellarAddress.fromMnemonic(String mnemonic,[int index = 0]) : super.fromMnemonic(mnemonic){
    final wallet = StellarHDWallet.fromMnemonic(mnemonic);
    this._keypair = wallet.getKeyPair(index: index);
    this.address = this._keypair.accountId;
    this.secret = this._keypair.secretSeed;
  }

  stellar.KeyPair get keypair => _keypair;

}