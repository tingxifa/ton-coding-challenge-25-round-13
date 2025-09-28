import "@stdlib/lisp-lists"

tolk 1.1

// 用户操作记录结构
struct UserRecord {
    timestamp: uint32;
    operationCount: uint32;
}

// 合约存储结构
struct Storage {
    // 全局计数器
    counter: uint32;
    // 只有操作过计数器的用户才会被记录
    operatorRecords: map<address, UserRecord>;
}

fun Storage.load() {
    var data = contract.getData();
    var slice = data.beginParse();

    // 检查是否是首次初始化（空数据）
    if (slice.isEndOfBits() && slice.isEndOfRefs()) {
        // 返回初始化的 Storage
        return Storage{
            counter: 0,
            operatorRecords: createEmptyMap()
        };
    }

    return Storage.fromCell(data);
}

fun Storage.save(self) {
    contract.setData(self.toCell());
}

const OP_INCREMENT = 0x1;

fun onInternalMessage(in: InMessage) {
    var body: slice = in.body;
    if (body.isEndOfBits()) {
        return;
    }

    var op = body.loadUint(32);

    if (op == OP_INCREMENT) {
        incrementCounter(in.senderAddress);
    }
}

fun incrementCounter(sender: address) {
    var storage = Storage.load();

    storage.counter += 1;

    var existingRecord = storage.operatorRecords.get(sender);

    if (existingRecord.isFound) {
        var userRecord = existingRecord.loadValue();
        userRecord.operationCount += 1;
        userRecord.timestamp = blockchain.now();

        storage.operatorRecords.set(sender, userRecord);
    } else {
        var newUserRecord = UserRecord{
            timestamp: blockchain.now(),
            operationCount: 1
        };

        storage.operatorRecords.set(sender, newUserRecord);
    }

    storage.save();
}

fun onBouncedMessage(in: InMessageBounced) {
}

get fun getCounter(): uint32 {
    var storage = Storage.load();
    return storage.counter;
}

get fun getUserRecord(user: address): UserRecord? {
    var storage = Storage.load();
    var result = storage.operatorRecords.get(user);

    if (result.isFound) {
        return result.loadValue();
    }

    return null;
}

get fun getTotalOperators(): uint32 {
    var storage = Storage.load();
    var count = 0;

    var entry = storage.operatorRecords.findFirst();
    while (entry.isFound) {
        count += 1;
        entry = storage.operatorRecords.iterateNext(entry);
    }

    return count;
}

get fun getAllOperatorAddresses(): tuple {
    var storage = Storage.load();
    var addresses: tuple = createEmptyList();

    var entry = storage.operatorRecords.findFirst();
    while (entry.isFound) {
        var userAddress = entry.getKey();
        addresses = listPrepend(userAddress, addresses);
        entry = storage.operatorRecords.iterateNext(entry);
    }

    return addresses;
}
