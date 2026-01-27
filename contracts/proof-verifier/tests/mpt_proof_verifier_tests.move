#[test_only]
module proof_verifier::mpt_proof_verifier_tests {
    use sui::hex;
    use sui::test_scenario as ts;

    use sui::coin;
    use sui::sui::SUI;

    use proof_verifier::mpt_proof_verifier;
    use proof_verifier::state_root_registry;
    use proof_verifier::condition_tx_executor;

    fun hb(ascii_hex: vector<u8>): vector<u8> {
        hex::decode(ascii_hex) // expects hex WITHOUT "0x"
    }

    #[test]
    fun test() {
        let mut scenario = ts::begin(@0xA11CE);
        let state_admin;
        let mut state_oracle;
        let mut tx_oracle;
        let mut mpt_proof_verifier;
        let start_block_number = 0x9a9a00;
        let receiver: address = @0xB0B;
        let escrow_value: u64 = 123;
        {
            let ctx = ts::ctx(&mut scenario);

            // ---- test vectors ----
            let condition1_block_number: u64 = 0x9a9a20;
            let condition1_state_root = hb(b"dccab55523b9ce5d012ea2f5134bd714b95b72100408d830a875a8fada21f2c3");
            let condition1_account = hb(b"ded4e253d606d27daee949b862e7a18645cda442");

            let condition1_expected_nonce: u256 = 0x0;
            let condition1_expected_balance: u256 = 0xb1a2bc2ec50000;
            let condition1_expected_storage_root = hb(b"56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421");
            let condition1_expected_code_hash = hb(b"c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470");

            let mut condition1_account_proof = vector::empty<vector<u8>>();
            vector::push_back(&mut condition1_account_proof, hb(b"f90211a0a221e1c700ee9fcf40b668c77383d30c0f022a2bb791dbba918ed6ec8046641ea0b3fc17f07c90ed501f6f57fc96a999b05fcdae234fcb9c224b301eb60c878093a057026301ef3d535893ae700d7e8da3cd63c749a960673cb713e432384ca9f1c5a0375bc0f897cf07ff96cd0fc3a928c2cd76345a346d020a687ae22fde20475813a0832ab0808221b4fe254d85bb59d74acc0e7996e70d4655e74ecfce4a0fc7d3cda009a240e799a495ff1496bcdfee5521cd427c391eeffb91ffc36c6d8fae2a0d57a0a9cb0191cb370c60fa76751a6e94959394314aaf2eb39061ff8b87771f51c24ba0a2c1a89344e1f967476be931d5711a6732a40e42cab68d9f4b8686fb200a2ab2a0664ece84d0173ef479dc1891c4de5f4ff38a51284e7577a839e0b97f7808bad8a02cfc427fab22fec5af82caa26e8d500c03da048295fd5f57b64c0c4aee847781a07d736cdb3683a2030293d68460ca0b817c5ad8f46d2307501d2ce0280764185ba0a95d1e493c49657e0b70e283d68f1cddd0b01fbf448e73d6f13c9ab5dbd82352a0ba0301a9d1f2492739ced99fb54b8a88b803ecfa6d339e82fa28c30dc06f6befa0651a5c5458f135082ae00cf83a69ac120f21ec3c227a19d8cdf436adf2ff5275a0b069ffbc99cbdbdc9831b885dbb250d8d8d468651244eb5b93fe138366a4a62ea0f3dd717522bdd15725dc8834208519bbbc9f2eabadee7007b44e5f71a7ccce5480"));
            vector::push_back(&mut condition1_account_proof, hb(b"f90211a00f1267da9036f1cce579781ef12de3f9f7562266376da2095f14f6d898ca2a84a042d33ddfca5d12215ad3cc9eb89d1d9d1abcabd7306b56e0760cfb1c2521715ba07fa1839f6a24d2e0977686d97c22dd72710dfdbb15675ab59741566103ed9d63a0e53570dd175f163518a6c7dc86fb05c07f7086b59b164b70bd2de35818834fc6a08edf89c3612fc17a7c8b36cf47bfb1047a3de27823f07e753b331809e97a7a22a0b2f19dc6ebe735a49af44992fb817ddaeae2d4a52b1a9fa02dcbaf796549df4aa076879427cacc97f5eaf234d5e00c0380df4011e4d55fa639f1e162eed144a061a045f2ae027cca63e0e57df4a6a71115267c75af20d5d2e5b70408e350e08462b3a0d7521440bb60d1bb4e6bb63ccce5176e8748e33065f49cd82c0d2368440d84b9a0d7970eb0e2800601336c666ec32260d0e7ed81de45c19b8a0d27ddfeab6f10f7a04c3d6142d96ab0d24f1902ea6dd5dadea0dd7b3a57afee9c46dbe862cad2ff1ca0136914dc2b73e786d7dfc8c0076f125d977ede775acea2d38d59051dcc22889da070c6a5e1a1acd6a7ea95f16ff10ae6c440fbb23236a3a328399b8a1518fb1eada0e08ac5634b6b01a3dcf266522881d298bd8d18c2860634dd2d0303653723b5d6a08d5bf371c1489604b5d1f944e86299e96c6aefa0d4c1a8511ffa9717cd71f402a0137a0617eb434140d9458611a1117c1dad62e68dbe96db7d85fb64fcaa28b85d80"));
            vector::push_back(&mut condition1_account_proof, hb(b"f90211a06e06040bb39ff043cfeb206f27f306895ff04f578964601d52566c8c02f5dc11a060639ac729a8fce5bb374990f72b64c0ab48177f25856b71c7df5511c5b9d752a0e727bfa75c2207cb6b83320ff13c5cffc833389692e998e96e5d987b6b1e1370a0ba108c3593339be15a5e825207a2c499f3b87dc6421cf8b28a7711e1c845a48fa08e998c06d01e1e3e8b99398627109d1488d19daccaf55024b01e8ac6b1435172a074ac7c86a79e9a3a26fa7038bd619f0be71aa94bc78df96b53c0e2525917ba71a00b0bcfa360b874b817fa007192f5ed0c291588783cab8e5ec81948242ab3c523a00f0ae444c7649a806705a1bcb2e35cf901f946dc84bf3880593e015d23bf09f6a0bab14635995c910605ad92566bb0950c3bb8a7728318920a9fb92884d6ce32f2a048031f347c39341ca64c3fabf5f0fe9c7ad59b02329a3336b263362b8850c8c1a086f96f878938bd9342babfd356e7dc9fe80e10f881bb486a14c784146ee14c5fa034f3b6a74450e0c45ec29361f3b91db6fa16000301ac6a2bf4e577fa3fe78b64a0ee028c43039d4036c969c9fa91fc196c46123b50aadcc1daecbd27ec0fab773da05d764b6f97d4943c9b1176fa0a400e51a403c96a7a72cc06a9f284528c614ae4a04e80115e98fd356148ab167ea101fba7d528cd9ef4e4d866bbed443f646812f6a00937d771fe9cca8f23c71e00b0f64d6704c7c367e93cd5d6fef4ed2c922ae3f880"));
            vector::push_back(&mut condition1_account_proof, hb(b"f90211a00e86ea17482df5314ef4965ca32dddad7fe6d8a61964dd279e8bd0bbbd4e3d70a0623039a8525752e2ed08df051398fbce14d4774b0ce63b777c1773b7dad3943ba08ec0cbda1b27cf3730e63cafbe6eecb2f10224b478de90f1983f3954d72418d7a061b8ffd8c33572691bb325b20f2e6d8f7537dd1f656e5fe67fc75c26230c12c9a01ceba2fd3befbdb7d77286bf5a45063ca204ae3c0da78ca4ba8fdebe6b37271fa0b5dcdbd4ee4fb6a52a166ca43fac5bce2e90ef3e5823cd25f5be14b218cf96bea088c5932e6bb4472094653fdd8793001c6d5516e94e779cd816ebfea28895308fa094439c12ce55363c6688797efb6ae2ba85401b6effe684fe3688b793eefedf55a087d4182bfd280b4127fe63575a5a31428c6b46f00cac7dd045a5c295e8ef80cea0b1e735a82e4f8a38c89b325a81211af8d2988a427c9112b4460d054342fc4d95a0af1c5dfdcc70c9dc652c1acb9157a3a07ab79a69ce510d7651786b8524cd3e2ba05ee90f6ade3aab54bf59693bf05256c4a7e1b7e5ab2da7a81013d1957fc5fa44a09a42e074ad4770a9cebb326edaa734c71d1cde96555dff6549b46e0340dc8ac2a0efe18519e193c9ec92deae223ffd2469e3d9cc540df7c9cb4ca8e32fd219030fa0a708d2a9e61fee9052d5d414120356474edd6f6f9cbcb7584ace9218ca6c7b0da0e9294e85929f353816256a385491eb35a08924e87be55f993060813cc801121380"));
            vector::push_back(&mut condition1_account_proof, hb(b"f90211a04da2c76b07b7b19551b6646914420ba30d2d6244a5e926bb7d259ce42a006b9fa020ff362e65284bb97ffc1416b17a073d5c191057511cfe796119e62e835997f3a005fe91e98075740e22e73909603e06c853b85ba7f789b8e3239383326a61bee6a0615d1ad29e4d4b15dab2c81dc317c7b04db3309e7adebbefcb51ebae0bdaaf9da0dafbdae410e007731cbe648805adbf9179c95de61a610dc538d69281dd813805a0038b12c41a8e256f0f99c8f5090559073ab956fd292c09a702dd48737a835edfa0501c9aa05ea7add198a9910ea9528ebc864e0c4c7fbe47e598a1bf27ed847972a025133073ac0d30cd0a0d5f3caef4bf72f7ac11ee3bf8fa8da6121c788f01eb66a0f90d11fd894d85e2b9f44325f93d25e22597ccd7fe573385d6e96687d3ea7d4ba02c43e4095de98ef1c838af44bf4fa9596a59586f8022f4c69274aaa925e09328a08ee641f13f428c766aa00e56bed20be5f9f7200e194e9ff5cd41bb54a32a0127a07ac0db9baf4cab8c9ad06370c49067930c7ff668ce0a71588361d3f8bbc1b057a0923b068b52f4622e0fc9d8784a9f7220ba5d2c450956e8bb5289b7a7b80917fea0756a0fb4927845fc73762cb2894597181371c5f2ac5c26fe29e6e8cde6ee63e8a0f92f8a499fa6434f8ce0d08c5d7d4bffd94a3b9a53855404b24dca62d1eb9ceba0a619920a36b2c2b54811687739b71f9113a27e6ab7db0ebb371eab32a146d48680"));
            vector::push_back(&mut condition1_account_proof, hb(b"f90211a08d7d4a348daae66ec8be92d9e9a80983bc103ef0471d02693980e26ed14899fda059895a488dff47fd0692f47d8e5d1dee8bf9806f3c446be00364e749761baa28a0502fe30ec6a06aa81e8bb2340bf417be03531779e9833832b85717aa2f722475a030650f5e6edbaceede7312f7208e7cb2df2bc5e41665de6ca5fa79ccb0322c1aa070df0460571d39c711b0a830bc2d2b227c19b40373ec911b744b14257f4f70d8a0d6617c0bb9e8298e07c58f3049724f5a34d25440d51786067bd44d03461daccea01282d09e7b0517f06797f893b027abbe624a76291f289df6f8a79a3d15e833aba0389360bda6bb38dc757fd4272fc2b50b27e65a4fa6f125c1190a37ee5634b026a017c327258d0335e23f936aed4ea93d35eca50251d567681eac633283f9427001a0cfd58e720cec0b485403a0f51ce68dadddb1166f23fa5e983a162c823892255ea051cd194f8b385d5ef83df7a8461cc31a87883eb2475d6acafed21fd0fe433da3a0523493f5ee8d1ea933463d7b54c77441a326aabfb7bca520944c1fd8f7413b33a0d3153b4ffb4469a255b06f3b5e4cf3368eadb703962c032d027a1d7785225bf8a0939a668adfecdec4de5a728b640b194db5c7ad01e4d721e7af6cf4d5236fcc9ea0ed1f802b52c60b051f62d9ff80240b19a9685a022878d7327d74d862ca13ffe8a0a1e99edfaa9759042c9620da36b6272ba6a82cd383c694144937aea86724491380"));
            vector::push_back(&mut condition1_account_proof, hb(b"f8d1a0631dfc483c3d2782c57a7f664a1b04628e123b2b1c2c426446a3efff4d09c34f80a09a86edffba83822446016d3f851f3af5c8c00cbce67a3f4112f859a93b33e4c5a0e28e46bb03f8c3839ea82f4884a8b1599b1327dcd14a26593d0aedfd01defa0d808080a0f4c25eae8b10438961fc5adc1041aafb4c4fda43f150cbe3796706375a068c2380a088df1dda664042bfde5a5d58a33034fc6c67bd45f3b005cf7f45afaa66a654178080a0bd335626b31826183f186990383643e63fb28ee6ae56efc4830140ae25d0714380808080"));
            vector::push_back(&mut condition1_account_proof, hb(b"f86d9d39743245be199d587d5f1d0f716a1259ec1e271c3626a8b35c6b497e43b84df84b8087b1a2bc2ec50000a056e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421a0c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"));

            // ---- test vectors ----
            let condition2_block_number: u64 = 0x9a9b05;
            let condition2_state_root = hb(b"ea3763ed034d08339c172be3e435db0a383f7e0ee8f3f00be7876ec920fc89cb");
            let condition2_account = hb(b"ded4e253d606d27daee949b862e7a18645cda442");

            let condition2_expected_nonce: u256 = 0x0;
            let condition2_expected_balance: u256 = 0x213b3b464cd0000;
            let condition2_expected_storage_root = hb(b"56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421");
            let condition2_expected_code_hash = hb(b"c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470");

            let mut condition2_account_proof = vector::empty<vector<u8>>();
            vector::push_back(&mut condition2_account_proof, hb(b"f90211a005a5807182e5366850d1b1381a0a13a9da8b2fdeb938209d9d35fbb15391973ba0207ff4296d08ca31a2713d491a6f7214c99e00c91517334dbebf057f54c6f422a0e032871ef8616b887c9e9f8bf8c855bb52114b98f1114faa55c51ccff90392a8a0ab7b642550a83f95224ccd85c67362ee0c34d4adffe9cca4318f09a35e529495a0ae906b14bcd8fed7f397e899847d714a0a810d08b702001aa3d177e268b1f2e8a06c341eaeb064707df8996d1f88057e99b3dcda6b2c8be40f9dfb4c3548b502d0a0c1e2fb3be38e72e1c75b27741c9d06fb45f9fce20040247478653dff226f273aa0bf637967c943b13692e817402e7e9f50554e0ca9733d55cb92a1c3562acd088aa0cf7d3abe5dbe1de96c8967425f65578505ae7621e96fd71b46f0df8e0a131a60a0546a8882d4c16f22df1ef863e1d9768a32c2253c7d6a087ef1118a709a95ca34a0037bd626012a16ac2ccfcf2fe594f9907e26940a2eae2f18aafe5c4f1f89b147a0688dc21941e214d3a886a6d3875c50f799a9214f61af473b611789e67a2260aea0633de924d837d85740fc2650874a1099e3387bdbfd6113a8d2132b9658642752a014a6c32cb6c7b4b22e822db14cc1c179c53b3d09d1f171a38b5da1ae99ac884ba07406fa8c6c6a553b16c489b271bb8123599c9bbb9ee659c6e3f27b0fb4c6bc38a02c03cc939a53bc4ef5a48a717ccdb281dfc62b8231ddc1751474c9052113d93180"));
            vector::push_back(&mut condition2_account_proof, hb(b"f90211a0b636232fceac385e9607c87d833d4c0a30abc3dd7dc96380e73573f14c2dd96ca00dda6bf0a9ffed4b73dd4288beaaaa674c6a3f152b56ff74ce7d15ecc040794fa01aaa63ea5d9fcab5b0b0a8d581243335246ac9335da9460fa813db3ab8568a7da0c91650a2f49961469f7b17797887eb529050742b31bf368679057c282502a377a0af81b2265d59ac4a43387cc5cb1dd64771cf631f2ce7192c0668395584df4117a05861c716667cbf30755df68a5d6a9f7eff3b5da5788e4c7c3bc4b7a5a503b09aa07fc00761a3481b2d779f3791f3975b85c095bf80c14b44d590f79f3a8f180874a0c53163c5380176b6153a3217d16078bd65136d2d01d9fbc2a600432a328d01a9a0d0ee0befa4b6c91d78b6efb36ac28b61c993888f9906f6cf8f905f2383e65478a08d4251cd5b23be359ecd93f76a960ec87120fa67e7d70096732550dfa44d0d62a0d8e5ab1c8a92b99d4c413bed1ae9f8606bb1c6cff0312106da17704b4cb2bd0ba0b840113fa34229a5d41f17cbed665e04552329a7f61a555568ad6335544081f3a056ac0acf93c905d571be5dbc59fedc84983ea9cb2eda73ff102a9e749969e285a0858d6cc24805657ccb16e0573649db4bbf43be3f592fb218a12377a77a75fb08a0022c33b2b6e89afcc41ce62d88eb0895e55926f5b2da5c512fa7a1dc6a305431a0323524a882475784c2a525b57071d47c29926c1d55ad294e77ace24ccbd598ff80"));
            vector::push_back(&mut condition2_account_proof, hb(b"f90211a0ca58484a1db20173576491abb41cf34c3eb24e1f466831b5a72460d73738cc06a071df1e7c9489a528b7f047e387062f3fede36fd69a29dcb8df8a345b2ba03bbea0d8a8564d7ace18cf312cc3f4e15661d230e31566cf30ed6b1bcf9c7248fcab62a0b0ef4f3b5bde571828def22879e92229b9ebbaad762dc3ba1e1e6ff83dbb1d82a09f2d27f85f1d99af71ec91081469a5295d64cc514d3eb9b4df99e313c460c48ca0beb3dd9b7d214c0bbfea5673391ec28b7dadcb9419361c99187dc1b1bc3f0634a0c79ecaaba802dc110a8beecbdc068f1efab4b7996c12d5120381df2565aca43ca0834ed23e8c583c6808a79572900778c190ba2efade389df414a5a5b3e989abf4a0999b0b240c7f3f65c0e8d1f52ca788ac48b9fd4779ffab5526b2ef7c8cdb6266a01adaec52ff5546d7830deb604f996a5a16ccb796b175c11ac64a79c533986e8aa086f96f878938bd9342babfd356e7dc9fe80e10f881bb486a14c784146ee14c5fa034f3b6a74450e0c45ec29361f3b91db6fa16000301ac6a2bf4e577fa3fe78b64a0e1a625e2fbde8dd6b9df367fb5c8b692000cec7d21e1a82635907b566eb98daba0e38af3b2bc64a02c4f6e454488e958e8cbfbadd2bc95093d1ef46c6cea2c592ca05a8cde41795aaac67bfd0a6f85b8be678285293e497e25f30ddf537005abe42fa00937d771fe9cca8f23c71e00b0f64d6704c7c367e93cd5d6fef4ed2c922ae3f880"));
            vector::push_back(&mut condition2_account_proof, hb(b"f90211a00e86ea17482df5314ef4965ca32dddad7fe6d8a61964dd279e8bd0bbbd4e3d70a0623039a8525752e2ed08df051398fbce14d4774b0ce63b777c1773b7dad3943ba08ec0cbda1b27cf3730e63cafbe6eecb2f10224b478de90f1983f3954d72418d7a0c561ab04fd497de4d31bd595b8b30928ef079d5b9ef27a0abf8034f5bce92eaca01ceba2fd3befbdb7d77286bf5a45063ca204ae3c0da78ca4ba8fdebe6b37271fa0b5dcdbd4ee4fb6a52a166ca43fac5bce2e90ef3e5823cd25f5be14b218cf96bea088c5932e6bb4472094653fdd8793001c6d5516e94e779cd816ebfea28895308fa094439c12ce55363c6688797efb6ae2ba85401b6effe684fe3688b793eefedf55a087d4182bfd280b4127fe63575a5a31428c6b46f00cac7dd045a5c295e8ef80cea0b1e735a82e4f8a38c89b325a81211af8d2988a427c9112b4460d054342fc4d95a0af1c5dfdcc70c9dc652c1acb9157a3a07ab79a69ce510d7651786b8524cd3e2ba0a80ca141372f763a403b809c43af172c29008554e8d1793d5ecbbdc04b63a52ba0400276b16b15b5728b40115dadb77b5ed09841f11a1b57d4474ea1d3b567a2d7a0efe18519e193c9ec92deae223ffd2469e3d9cc540df7c9cb4ca8e32fd219030fa0a708d2a9e61fee9052d5d414120356474edd6f6f9cbcb7584ace9218ca6c7b0da0e9294e85929f353816256a385491eb35a08924e87be55f993060813cc801121380"));
            vector::push_back(&mut condition2_account_proof, hb(b"f90211a04da2c76b07b7b19551b6646914420ba30d2d6244a5e926bb7d259ce42a006b9fa020ff362e65284bb97ffc1416b17a073d5c191057511cfe796119e62e835997f3a005fe91e98075740e22e73909603e06c853b85ba7f789b8e3239383326a61bee6a0615d1ad29e4d4b15dab2c81dc317c7b04db3309e7adebbefcb51ebae0bdaaf9da0dafbdae410e007731cbe648805adbf9179c95de61a610dc538d69281dd813805a0038b12c41a8e256f0f99c8f5090559073ab956fd292c09a702dd48737a835edfa0501c9aa05ea7add198a9910ea9528ebc864e0c4c7fbe47e598a1bf27ed847972a025133073ac0d30cd0a0d5f3caef4bf72f7ac11ee3bf8fa8da6121c788f01eb66a0f90d11fd894d85e2b9f44325f93d25e22597ccd7fe573385d6e96687d3ea7d4ba02c43e4095de98ef1c838af44bf4fa9596a59586f8022f4c69274aaa925e09328a06ff73e45453c3b5051bcf56c983650dfd6e3fb9ad0ea1a0139706550f5863630a07ac0db9baf4cab8c9ad06370c49067930c7ff668ce0a71588361d3f8bbc1b057a0923b068b52f4622e0fc9d8784a9f7220ba5d2c450956e8bb5289b7a7b80917fea0756a0fb4927845fc73762cb2894597181371c5f2ac5c26fe29e6e8cde6ee63e8a0f92f8a499fa6434f8ce0d08c5d7d4bffd94a3b9a53855404b24dca62d1eb9ceba0a619920a36b2c2b54811687739b71f9113a27e6ab7db0ebb371eab32a146d48680"));
            vector::push_back(&mut condition2_account_proof, hb(b"f90211a08d7d4a348daae66ec8be92d9e9a80983bc103ef0471d02693980e26ed14899fda059895a488dff47fd0692f47d8e5d1dee8bf9806f3c446be00364e749761baa28a0502fe30ec6a06aa81e8bb2340bf417be03531779e9833832b85717aa2f722475a030650f5e6edbaceede7312f7208e7cb2df2bc5e41665de6ca5fa79ccb0322c1aa070df0460571d39c711b0a830bc2d2b227c19b40373ec911b744b14257f4f70d8a0d6617c0bb9e8298e07c58f3049724f5a34d25440d51786067bd44d03461daccea01282d09e7b0517f06797f893b027abbe624a76291f289df6f8a79a3d15e833aba0389360bda6bb38dc757fd4272fc2b50b27e65a4fa6f125c1190a37ee5634b026a017c327258d0335e23f936aed4ea93d35eca50251d567681eac633283f9427001a0cfd58e720cec0b485403a0f51ce68dadddb1166f23fa5e983a162c823892255ea037c9195335e2d613eb0cc63634fe210f548b683690540f51f8bc414930f7833ba0523493f5ee8d1ea933463d7b54c77441a326aabfb7bca520944c1fd8f7413b33a0d3153b4ffb4469a255b06f3b5e4cf3368eadb703962c032d027a1d7785225bf8a0939a668adfecdec4de5a728b640b194db5c7ad01e4d721e7af6cf4d5236fcc9ea0ed1f802b52c60b051f62d9ff80240b19a9685a022878d7327d74d862ca13ffe8a0a1e99edfaa9759042c9620da36b6272ba6a82cd383c694144937aea86724491380"));
            vector::push_back(&mut condition2_account_proof, hb(b"f8d1a0631dfc483c3d2782c57a7f664a1b04628e123b2b1c2c426446a3efff4d09c34f80a09a86edffba83822446016d3f851f3af5c8c00cbce67a3f4112f859a93b33e4c5a0c823836e1d11efc07a161457843591a79d211dc5077204ab9411b1cea2c6e06d808080a0f4c25eae8b10438961fc5adc1041aafb4c4fda43f150cbe3796706375a068c2380a088df1dda664042bfde5a5d58a33034fc6c67bd45f3b005cf7f45afaa66a654178080a0bd335626b31826183f186990383643e63fb28ee6ae56efc4830140ae25d0714380808080"));
            vector::push_back(&mut condition2_account_proof, hb(b"f86e9d39743245be199d587d5f1d0f716a1259ec1e271c3626a8b35c6b497e43b84ef84c80880213b3b464cd0000a056e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421a0c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"));


            // ---- create oracles via test-only factories (no direct struct packing) ----
            (state_admin, state_oracle) = state_root_registry::new_for_testing(ctx);
            tx_oracle = condition_tx_executor::new_for_testing(ctx);
            mpt_proof_verifier = mpt_proof_verifier::new_for_testing(ctx);

            // ---- submit state root ----
            let mut list_of_block_numbers = vector::empty<u64>();
            vector::push_back(&mut list_of_block_numbers, condition1_block_number);
            vector::push_back(&mut list_of_block_numbers, condition2_block_number);
            let mut list_of_state_roots = vector::empty<vector<u8>>();
            vector::push_back(&mut list_of_state_roots, condition1_state_root);
            vector::push_back(&mut list_of_state_roots, condition2_state_root);
            state_root_registry::submit_state_roots(
                &state_admin,
                &mut state_oracle,
                list_of_block_numbers,
                list_of_state_roots,
                ctx
            );

            // ---- fund vault (so split/transfer can succeed) ----
            let escrow = coin::mint_for_testing<SUI>(escrow_value, ctx);

            let mut list_of_condition_account = vector::empty<vector<u8>>();
            vector::push_back(&mut list_of_condition_account, condition1_account);
            vector::push_back(&mut list_of_condition_account, condition2_account);
            let mut list_of_condition_operator = vector::empty<u8>();
            vector::push_back(&mut list_of_condition_operator, 4);
            vector::push_back(&mut list_of_condition_operator, 1);
            let mut list_of_condition_value = vector::empty<u256>();
            vector::push_back(&mut list_of_condition_value, condition1_expected_balance);
            vector::push_back(&mut list_of_condition_value, condition2_expected_balance);
            // ---- submit command ----
            condition_tx_executor::submit_command_with_escrow(
                &mut tx_oracle,
                start_block_number,
                list_of_condition_account,
                list_of_condition_operator,
                list_of_condition_value,
                receiver,
                escrow,
                ctx
            );

            // ---- verify proof + execute ----
            mpt_proof_verifier::verify_mpt_proof(
                &mut mpt_proof_verifier,
                &state_oracle,
                &mut tx_oracle,
                condition1_block_number,
                condition1_account,
                condition1_account_proof,
                condition1_expected_nonce,
                condition1_expected_balance,
                condition1_expected_storage_root,
                condition1_expected_code_hash,
                ctx
            );

            mpt_proof_verifier::verify_mpt_proof(
                &mut mpt_proof_verifier,
                &state_oracle,
                &mut tx_oracle,
                condition2_block_number,
                condition2_account,
                condition2_account_proof,
                condition2_expected_nonce,
                condition2_expected_balance,
                condition2_expected_storage_root,
                condition2_expected_code_hash,
                ctx
            );
        };
        
        ts::next_tx(&mut scenario, @0xA11CE);
        {
            let coins = ts::take_from_address<coin::Coin<SUI>>(&scenario, @0xB0B);
            assert!(coins.value() == escrow_value, 1);
            coin::burn_for_testing(coins);
        };

        ts::next_tx(&mut scenario, @0xA11CE);
        {
            let ctx = ts::ctx(&mut scenario);
            state_root_registry::destroy_oracle_for_testing(state_oracle);
            state_root_registry::destroy_admin_for_testing(state_admin);
            condition_tx_executor::destroy_oracle_for_testing(tx_oracle, ctx);
            mpt_proof_verifier::destroy_verifier_for_testing(mpt_proof_verifier);
        };

        ts::end(scenario);
    }
}
