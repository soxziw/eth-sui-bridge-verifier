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
        let tx_admin;
        let mut state_oracle;
        let mut tx_oracle;
        let mut mpt_proof_verifier;
        let receiver: address = @0xB0B;
        let escrow_value: u64 = 123;
        {
            let ctx = ts::ctx(&mut scenario);

            // ---- test vectors ----
            let zero_block_number: u64 = 0x172b8ce;
            let zero_state_root = hb(b"cb07c9b25d3070b7567fe0f9d7d5cb7600d910a20adc307fd1897ad55139d07c");
            let zero_account = hb(b"936ab482d6bd111910a42849d3a51ff80bb0a711");

            let zero_expected_nonce: u256 = 0x1;
            let zero_expected_balance: u256 = 0x0;
            let zero_expected_storage_root = hb(b"919b50579c67e3b9cab9c7ea4354a24736ef7c245e2e7de22b7423f456037993");
            let zero_expected_code_hash = hb(b"fd27e945721856813b050db524fe063f6fe568c051e3428c51c484f59e85e583");

            let mut zero_account_proof = vector::empty<vector<u8>>();
            vector::push_back(&mut zero_account_proof, hb(b"f90211a03660943f1da12340bc381226617fc6423de2fd08e208b380941713364fe4521aa0ed4b5279ae6be45ec339f816ab41b339ec494464cf905a91bf2cf66366d11ef9a0863878b7b937621d4c06d5a8ae2851d2c36b14bcb9a1829ed2e5863b2c5bdd70a03cf50ad24184cb3981ac082d7559891a5b26293b3176e0aaca727b8898d3a918a0aa133bd05a7c8b2f5438f933d58a14c4bae364de6a8d2bd5f6332f51a302b05ba04b3d1c928c8ef8bc4a20bc95f0d244c6688a9bd85363a53933fb5bae0bd1bf8ca0bd92e46c03a0d3d3342d3d8aab7f80f8eaa09cb68d6b68f199fb79365d6c0025a00d623a5811afcf2a5d63f5113f70e36c25a5df6cea3af39beab6b2fed4e78d99a0116e95843f2dc1bbf3a4212b25e237444e4385c111b5402e77bdc97862a5a630a046c92b64849e3130f90aefc1b77cbfcf6e360649a47e77469e65002f5a8e6342a017a308010cfe416038aa69b87affd4162a71489226e1c5c8c9236d7e962dc292a09a941513e208820602fd8f13f8ca8cc70e958bef6f47c900f034f0c02177da11a0d989c75b26c7e2bb56971499bda02b6b5e976a0d8205436ec337214767b379d7a023bf41230be5316aeeeed57f3622b14beee4eec852f955fafda61e43effa0db2a07d7dfcd00bac5531273056238ee5ca09a9f57c924802f1736e246625d426abfea0c7323466813704c89c2461e4dd968effe764106ffc8f376162e3acc01a53298680"));
            vector::push_back(&mut zero_account_proof, hb(b"f90211a0b3dd7cf74078b707f55172beea9d38ecb0aab4dd0bbefd80e1042cea0148212fa0f844f7b5247331d01b9c6030b7ffdb0b914087660e3b5f25c7d7ca86ffd20d91a064bdbbbf4e2e5806939b3d92c2bcd847691027a201ab4cc24eabb5674ec1a70da017c3b34891664c3068a236cca1431a53d70dbe0b5895d675e8a469f5c3369973a09432f5dc58fc9f0cca5115c411142a7e947d4205550c7494dc0cc44b81892571a0bf22110eb708a5db0c6e9c3696634fb65e6e102b23123e82cbb0fd3505ff75c7a06458f2518d34719fd13a9388847113fb1a515ad16dfff9025180f965941a5ffca01b72a9634d2bb25d46622ec94166381b7f44da4ffeed03319bb6d7c9a4c6f56aa09d3c1b9c15c31f71c8644183939160e8af543ffccd01c00eb04557b1317aff25a0741718b3004bcc5a8a1da1a2c9dbc1de9c4086cad23d43f4b4405d82e21e9917a0ca446b7d98eddaef959b426f1d0bbd0c14251b774beb0cd27316948034a1e61ea06aa28998272caf33ff9db80f390073e85a53c47d244cabb3091b1f31f18eaaf4a0b1f43614330140582d78dd39fc7e1dc8faeb5ae1297932f7ea7e4f262c37cfbca01800f0f86e4e6068dad22460862745edb1daab026b6a16724d77fef38e43f6f2a0dad2dcf06fed74748d1610a0d100c8382b1017a02b8d2764dd22a545020eeb2ea00dc6d8dacdcf7b333b7e3aa0367645fadd4456a03a31708214b77fc5bbd8136c80"));
            vector::push_back(&mut zero_account_proof, hb(b"f90211a020f793e092f881a069bfaf978549340088c770488ec138f72e6afc7bd2fad160a015e5bea2a9ce0bbf49f9b4c17d950e662cad1bb9ec05c069dfa8299ed6776c69a0e4a53c717584b021f6d2f5539c60166cc08566c2bbaf1afc0f8e72ed85dd8a90a05d36682772d31699b531befc520fa0f21eeb8fbc27e4dd463e40379435521f03a08f49a4f853a6d0c44b4571f16f516d2ce4692b94b790e5ff6db802fd64d9280da0d3e8d2267ea145fed2f5ecc1610debc27e1d6a2652f0c8086032307089208a40a01606a9842f84fb0f6ec518015c893a762e6a9a9959374c56a1edbba9bab72d1ba01b7e10e3d5a0378407cb5dc773135fd1613ee3f216b836861c3fd41d80ad519fa02d4d07f190c6802a1c5c95915f59020891fc93f211403c25c7421d2c345d4c75a08d0b57bcc9ee730d4de10884e53b605584e802c460981ae29d2dd337b0cf0697a0285f10643701f12ea1b6b7f0bc3d41e0c29972d0c06c09c5c07ab7b89d2b6112a0abe4b740f98d9640b67801288c48ff92e36f9453ede7887e9d66e153cebe7bb8a0e7944182364e1bcb398ee69573512f61136fa0756e619adddbf773316f279dcfa0cb77022c3b88b6ef9e95ea04ebd97e55f3937d4fa28af9bca9dc2e3b27908775a0648259c23cd234433f499fae1bd3eb18de60a6c3603b47c35fb98c5005e65850a02b0a75a64e24a3a5353ba59b028d18ad8c74fc06bb20ecbe0751a2f4875b255180"));
            vector::push_back(&mut zero_account_proof, hb(b"f90211a0d436fed1c714844acde511767e2d8287625780ef2c7bb22c23cd2f26d3ef1d14a0c6525dffe6546224f6a2e891617e9262a3156a3b4f83d514e90b0f628997fa6fa03c349c20fedc422d5f3ce0b367b2c6f562fa9585eaa383858afe07cc3e434a79a01491282b158758af0c01af1d4f0036bc785cb74ffd0919a89956f4baebee2f75a05bbc85e084f117ddc03cec426fa694f67ec8ed67247756f3ab49ea4a96c12701a04e0cfd1f2349b8f370f7234ebe9007529920dc3153bee42d77fdf5194b958ef3a053426d05b6f0ad2aae2c609ad01ec498e73a275ced4b9b043ef83d971d8b9f05a022e12657df584551a0b2e587ee6ce243e799e33721cac0c1ba09ea8eb87de3d2a0c0a263250f737a0338dfe7561fbfdc9c07476fd93ed1f2b8f1b30f60d257e527a069ac5add5e8251f7ccfba6ed606b20c26d76df89f03286fa3fdd09f466ad366aa0dbe9b45a9c6126ea9f9dc255f3b07af74c2b84c46493ba1c6261dc06915e38b5a0d02dc951b4b72c815f870f61bf7f55f607a3ab63b7430452d3dacdbbea94df73a098bafc18028c32b0d961eeddfd059516e062e7be9d3046f4a04d88b5dbd16f9ba08a0d1e03a65d9ce0bf3719a884b36addfbbbe937daebbe89ffdb295f5928759da03867ee5fa4d4c45d66fef52ad0ceaa0f46b49747036649ab24c89e8eab65ea71a07464865a7fb69eee63d3b8817d15b7dba42b1050181de9ede702c3b3d1de93c580"));
            vector::push_back(&mut zero_account_proof, hb(b"f90211a0e2555593e123d9f2f3ca188eef3883bbdd4c143ce2e5c7733e6dfc5a818f27eaa0aae206ec5ee5bc08f751f252e61c4376d06537baca8129e4d62efb6cf3420065a0158817e6114b96846431d598a16e5c227bcde1974688d1efe7903d0fbfd0a232a0a4701620b03d1380404fecce231cf544bb639cadc5a324fc0e8867f038a79990a0732837c4f5de5a1095ef9e9b6e67663d3f0a148ff9f21c1a6f60e276908a2759a0f2b0313d7bc1e8c10bc2ee60bbbad582be0f0c1517cefa228b07812ec6da6f4fa007e1eb27f7c1275b26dce60f3da8b2093f16a3ec12df3ce2798b42088c7e8610a090b1086a016cd021fb578e118a7a4660c74b8fbbdd72b76645265d5876ab8056a0bcd8b43db9968066b17a36a53eeee06c725301a28354c893ab19edc90c380655a0a311e0e24a9281a00b89af81e29b88244670f7c2ef8684fdee20169c411c0b0aa0b3c1f583b18fb8c9b9774c4b64ab6735145d7625dec355bc25a762f83fc5e3b2a0423cd15ced07a85c76a04cb4e9d9728c09a2fb39f4e9e5acd5e8fb379d421ff8a0beac93eb04a03c505f76ee829d64cf0a8ff534e9ba09ebdf490096c1de2ea773a071bcf8073c12de35ed6f1f9cb06d34485827ef0e48f5a4dba31204453486d636a061764cb48fd8e6fdf3a6a1b64dad1e0ab82a6ce6ed5a6ef8a675d28f2f45636fa061be86593298ee811eced099ac93f557b4fa1b09d023c9320ce71e1cca4b825280"));
            vector::push_back(&mut zero_account_proof, hb(b"f90211a03dec9e89492c0b6680c3feb20f87f1f93fa1da4474714f197778341dba00fbb4a0a745d14358135bcd1548ffba7f24cad541b90da1cd6355a37aa5cea7f8679888a04f0fa05236bcbd3658defd88b8663b0716a9c823b249d3ce550029da2d79a1b7a07d80f0370589397d4b2570e4c3e62c8ea2eb1cc8c14cc010c742e6870b2030c6a08345cef1960d6d8b9d7901c6950386c078c683d6494e3fe3bd0b0e3ef5a2f478a0df6073dfeb8e4febbf8ba0dd62e79ab04fc603d6859c27d48a3a65d46efa63a4a069e48b80d70eb0bc3e3c5bb849515e5cf8ff99bdb572ccb534ce02e8ec403eeea05fa82bb27c633a5279fc5ed8f9b7c2f568eebca862f6c2819f19d7bd6ae82412a046f141a4470adfba5c6e95185f52c57eb4667c53cc69a5eeb8b8fb6f0cd23253a024ce4d013bb92f139826be970ac0b4f234a31a154f9a89759ba4c366d96798d0a0ff0ec5d0a5e01f91521a6172ba8d5452e70a803d8fbae863ba8e7fb66fe1ce5da0ace61a8c5ef5e1fa61e502f1bdda7552affb95c3338749c7af5456be4220b940a08ec3b612cc66f454731460582cdcc717ef4edca3e1d7e2822af97692f25500a7a0eb4d16641ca34826de0a2bc567fc682e29b33170ef1cef27bc54611b84a90022a0e33adaedafbc1c3c4746b4cf5e6d322934df50f8e1bba8e0b95ac9d1602034a2a0f4413be0609b76a863a44afe548b62ddbe7c31e80b847e963a324e40739f6c9280"));
            vector::push_back(&mut zero_account_proof, hb(b"f90191a0e3e9b5a7b4c0e045adf4e56f65282e2bbd8bce76dad40af81164064729a22527a0b514d945dd760778d09d54858add2223281092d29fe3d8a23d346575df2071f7a0989c743cc832b8c05f446f6ffdab1b54f3415ef9ea4956c9d7f2151e60e9c01da00a9cae66b2290ab6f847200b1c5e73c05d571c62a9d3473e9472f10c14993649a0aeb23ab0e78e90d80ce55535213e55115abb03191080dcdaea4923eea66c229f80a0b41e5a05d93bca63c24e0d4f13fde61d5146470ad7f02af1d40d49e7ad3e632ea0dea0db9a9ed0f4d17afc17c5f300bf9bc31d97cbdb8979062f629780e09cfb3aa0bef0b275e9021e7c9166174485e6420d15c80f744091e23ed39173ce9435194aa0300be527e5c3342327647cdd88939844f6734e0461fd7cc9e5b07fba8767d059a0f0d6fc088cb6e1ffad1524ad60e00b0cec607a2a3a9d31b19831ef48525de4c1a0b56af5a5bdd6319ce841f77b04de4d4d28f548931ef4ff46d1e4eba84efc1bf9808080a089c69e669cef80f2f997fb6a1cd45e6af07c93d06519e5bac8f50219bfb8099e80"));
            vector::push_back(&mut zero_account_proof, hb(b"f891a0e8eff252408dda89b94dd010b02761be1958577614fde06a818c704dab5cd8e880a0f13d2d425dfb8cfc27c82b6265f02eabd96b24d73a5a9a45659a2010f59120ae808080a0aa6b75e137596faaf959236abe78b2c89f92a77bc26ff596caf65ccc5e72685580808080808080a09e8ef01217a411c0d1853b5b9c42b32e6a424dd0cfbc8452c61b5f7b9cb220298080"));
            vector::push_back(&mut zero_account_proof, hb(b"f8669d20fff57ed32f2b7e84c19d3f3005f3f603cc47be05d8a2fb5d744fc590b846f8440180a0919b50579c67e3b9cab9c7ea4354a24736ef7c245e2e7de22b7423f456037993a0fd27e945721856813b050db524fe063f6fe568c051e3428c51c484f59e85e583"));

            // ---- test vectors ----
            let non_zero_block_number: u64 = 0x17159f1;
            let non_zero_state_root = hb(b"f2fbda72af80ff49713383cb988697dcfabc880832eb91fafbf7e79257846a25");
            let non_zero_account = hb(b"6c8f2a135f6ed072de4503bd7c4999a1a17f824b");

            let non_zero_expected_nonce: u256 = 0x899;
            let non_zero_expected_balance: u256 = 0x470de4df8200000;
            let non_zero_expected_storage_root = hb(b"8ca3995950f1fc20246582dffab511b23061b51c08b9aff386fcb75c6ea1a52c");
            let non_zero_expected_code_hash = hb(b"461e17b7ae561793f22843985fc6866a3395c1fcee8ebf2d7ed5f293aec1b473");

            let mut non_zero_account_proof = vector::empty<vector<u8>>();
            vector::push_back(&mut non_zero_account_proof, hb(b"f90211a027bc50bbca04f85241a99a40852e13831e1500b496a842fa32541bd86bbef8b0a0b53ce3367aec31c8fe43d2601c7833e11f2cae68b776ae380005edd0bdeff3cba095c40c94080db8df889ecc933ea773135099b330a306feb10b8489c61ed9f471a0458e9adf759796bcb8a7708226d712a93f4f20c9218030ae4799ebbb15fa05f9a06ca72dddf9a283ae663830fbd5bd278f354bc788232c8bef00ef09154a9ad3c1a086c725dc1924383b8e935a913e9012ee0d4605ee62b54257f14ee94e4cc72f84a017a4b50f1ee236f92a772b2ad00a0b890e4a7659a6548599baf36d5d4f11999ca0e7646406ebb266d7490f19736b485dee044224306533b5acf3eca81d5ae90f13a00d7c9c1ce7710aa22f0488138140d86000c67b82e8c69a21bbb6465d205d2e0ba0430fc5d25b7158cca3117167bf37f8e897a0fac121ccbf07a52709a4d00fab9ea0a074bcd562fabb721a47e26b6e8ca0c743cc24f27b28750856a7acc2d9e38471a036e3eef9a1798009929d6fb6ea77514f6fe9ab81d844adc6e1eab03c4e8f9821a08a82e6ef2f50f6bcf67619f478fe24b65957c6ddf555f90f00b516e85bc885f2a0f30d66c402f2b3c86bfbfa7f12463fcf0313bbdc4b02a55457db582d55f4c42ba0684cebab5b716830d49b29123a42f3aef699e0166bd3ddc77efcb75635b329aca02649818c9ddb6a40ea978fd568698324668239e82f8987343a0f3e4e07891d0d80"));
            vector::push_back(&mut non_zero_account_proof, hb(b"f90211a086a3061a305b5712147705e1571681e72c8532ef8621a038c2152a2f281eaaeca068ada466f8e7e5bd86ae4c7e280640f208fc790a06a4aea806e0fd45d6478b72a0aed4a1269e8f0cc0d651af39cac2547465d091809273d8c05362c9759da2ccf1a01055b07135ef3a8dd2c6d9032625b52e9373f72147a5f64f85e5c40610c919d4a00a0e5fe87e161e083f47e983b4bc1d9c242f07634b7c1aceb79e30512b208962a0764a494678816a3d42747a5efcb4e0360e25cfb815cca1dc657e98dc6ec317c7a0a60887d191b2865fdf1606b7280b64a7f85a3f028a084ae9f4a6e2e8bf1fd1e0a0d75867ef3c0233a96ffddfcd65e99102186f5ee172b35f0acfa337db20302defa0c37d5a75b61dfccb0f779473678c881d556045ed18a8109b4ecb6308923c34eca08bf0e0d0334a1d0abb15eba2773dce58fe08fc0dac249abbf34f41c87bfb74c9a01b31f36c4b59533f9700f9421e2814d3a47f900ece1f4fe374e0a57f229b0cdfa0fe1c244cd77937a014645ff22a7591bf15a846910bd86aae1d7e4e022902c91fa06e47fbd5a2714bc52bad78822c0f68c2ba8de48efe112e6cce3d1aa0b91430cea00442f2181eb194a00560d02aeaba616f630422214a289d67f680228be50030b3a0f9c4cc0515bf1a175a593bbdd153f369ad504eccff4019a46cf1c6fecde2d927a06c529db80b6c44c8af2b8e178fd6c89e7ecbf7930920d83d174cb183a361f98080"));
            vector::push_back(&mut non_zero_account_proof, hb(b"f90211a0847b42b323f90d15beb2a3413a5f241d6eb0262105647f30adbd947ade887e23a0e80043bb9eecd4590eb0c26979ec7b0016c33d789118b1175d8104f06437c8eaa030bf16efd9068cecd31573f589338fe83bd2518bfeb27a8caad68d9424c9eddca0be5baa6fbbf9282e345143ba8f8b2d8801b8fcb0384a7acc942ee4b71d7ad2dba08df309e6b3dccf8270e90f4e7d812e2a43226e4f9a8afa510f5d84b68623b480a06c4aa0ecdcc314de6a1d339854e7eb7fafed1900f53a7527b04d57618110364aa0b4a9593b25f671663da8bd28963f71e9732beae0af50a800891f6f2c3c1bfbada039226e6cb2c9ef5f8089e5f7671ea4cb90f54074fab2df502a89d76d9cc6708ca0f8def8aa3f4b4fb8e8c2670fe0c690a7bfb30692725ddc751880942167342554a0772a94988fd54a0bdf41dc99f08c0829a06d35ee543e0b44325c9b5a57ad7588a0a285122272b8697745a5bd07e6a8620a21e03fcfd076ab38622b36b288e851c6a0ef311c1802910795aad1788ba7016e5058bb2a90181d0ada9609d3fab4f8fb44a09cef0202d5ac3db90b62ae5a7469cb931a85b0d25b04af0dc0b82f505467ddb1a053f331632812a928f1830c4871ce0f9abd04e89e4d5e7d673e568b0602bffb7ea0b52f273735b07a350e2c970a52e6df39ab9e5653e350ada73cb10d2e56060fd3a017b38d7d91a54c6636d734231c2b1e8e8af436a45435d857113c3a06cabba21c80"));
            vector::push_back(&mut non_zero_account_proof, hb(b"f90211a01dd3e948c230f63fbdb9f27c26a283157342f3727acb576b9bc26b073236223fa01bd485be50a1c8c991d429221a4f7a76ac78c429e46057e233bd905292d2b1e6a0df994e6c9bf670371feaea5c16b24dcc56cd28b18c03cb8bcb2cad8f7627bf9aa0f01227f298edb0ef207161df8db28a4e5099457c88e2128efa8ba8f5c6707715a0aac0852a5a424785dba1e828b08fd4b022df8c9fb5fb692f8adea26a9c6e43baa07428b54ff7f6bc34f4552801f7fd52e2e233d9545117fe0eaacd8428047aa7eca03f4d7c33c46a7cf794695ce85e34bba66015c0557554904f0c8c2a4f72135083a09b9343fd7d1e4212f9097a1a48cc169bc7074b93c61272347cc42904060967a9a0458fa195c2133f710303735dffcd1ec4a889569a046fc139a68f8d05fdbc5c50a0748b5e46b1cfac282efede0ef18baa0ede3dee3cbd7b7af1477cd86c8aa60b11a0a8c1b1a8b95831187e7742cf4f22be101fcb58eb249315f15ec2c99806f327d8a0dac27371c69115706939ceca30737e838b0e4c6f1a23af4356b30e2ee398b669a0033f9bd92fb7e7f885b96a01007fce2b5a2f5c605d11970925e66291131fb237a07a78e4f47e465faca489ac93c1c2b56ef4b1de02017971e4f974ca27825b4cd5a0b5007d1a451f7f7aae9d2c8546aaf966c068e76d7051a57e211d3e7865e3093ea0d108f082f9e7561a7356a8feda3bd1af62272eb3a1b4569a2e6225a5fcf2172a80"));
            vector::push_back(&mut non_zero_account_proof, hb(b"f90211a0fc36b90cc2958a5a5ad4b0daa107041976f2234b2b6e1ebf7faad0ac879db77ca04ff6e85ef88c847b27307923136785780160cf3079b02489487232c8a1ab856ca0990b9bcb835a9058f80ae18052b55c329741c63dc1f4f2d5c4709288f11d7e0ca0c55f4d3b813ddde9e8014561d026644201e43ac17618bc4329e9d0f583c36810a03c4a39a83bc2e2dbf0209a3d4b2b5a13a6fe1da49e353196118ef84af3dc960aa0f7f6bb9c70b84287688f54ad371384838f9bd448316613a2c12a398d404a69efa09e73d42218fb56425081ad444aba2169c6046beeb029297586eaa439353600eca02dc62acc298fc329854e43e7c6299fe5a049e4cbd168c87000cffe0bc06a5da9a059539ee989bd5c596889ebcefd514cb7b69e3dd3ebfa78b75f1802e340e74bf7a0d7fd1cf486359e4c06c0d36a0f618484440a15a971fe52f9ceb3706cafbdf719a0082d9e333272f028210e18d37aafec10229af5d2b980341c8e5fdae9230078d1a08731e07cf82d861bfc9d529c75f2406c53b5006b9c1d34316778134ddca9f749a01bf04a232a1c36f7af67fbb5be8a579b2315ed0226847e24c44738b933c7db38a017c0083bec0c86ffac54fb932add3636385de39376519d9ed6e55badef6c0ecaa0da9e58f977b0ae6d3ca459d92133c8d39c91f958572ca300419e7609cbd48432a0b4ddd3ff16591a9bc91631df89ad90e855603b3e1da9a5017f068b6275f6863e80"));
            vector::push_back(&mut non_zero_account_proof, hb(b"f90211a050eb765afd978cd1907e2f480159a52b8e3508f45eae170eaac59db13bc93496a05b257aa2f09ac67108cc7f9fd1a485ce4c63ce4070b04e01b653b31dd6be76aba015355f65f26109ed2157d06cb3424e9f534e555673b0ac0c3b628435e11bfb9ca01ec438e544e47f9021e12b50a16f241eec6d2240269a7c409d6405ede7e5dee4a0e72c7d892fef6b67a0c44c095f69257dd41cb47310978a432b38662dae29adeca009b5e082e24569d916cd29b938ca9224a0ca2f456bfeed60f7937e010c3ded07a04dcae1923aeb1860b210c815ab9e43bf6830d1eaa8cd030792d618d84602c9d6a0eeb2b9cbad4bde4ba47a71a28764c77e460ef056cd55fcb5fe9d2f0b6cfb67f3a0a86cf1b9cd3f80fe8d9572a5b6f3726dc19ef70360abf3f4eeb2152f46b3f59ba015177a4acebcb6716a1d0df5d517622501dcc8f7aa5d6fc01960c77ea01c9549a08adeb3b33517b97fca30051dbf8a3afba3aec01b52346e71f996859e09f99078a0ad426ab2eef7debff1ce3be33e199ecc64a5bd5c0990971dca377ca12080d7a0a02a56a23c17f09f836347e8b47d30f5379192579ee250912993a81bfee01a0423a0b9f2c6962f96cdb846c96c6f8c38d5d13045039df4b71da18953811f97751050a06e7e6471a46c1c33d8906c4a69063630775154cca75767ae183cb1754c362fd7a017a4bb0ed100cbb9a490c60eee317e18f6cccb11194439a82e987a6a1fed398380"));
            vector::push_back(&mut non_zero_account_proof, hb(b"f901b1a0e086d412cf136bc57fd38605643b3aaa3bd500468d4c3a33f1f6b89d54f09a0d8080a0f3529e8522b10b51de88de84fa18555d8eb730b2521d175641c89e0a494568f1a0d659f203eb939ef043019dbd6b0137d35ff24ba227c075cc9f56f67d101c97a2a0122cd3bf6f9ea58c3e74190eec6b6e6fac734e6305daeb7ef66ac32237d5732fa07a09a3670c2fb594b7924bc51e7e5e0ce2f1d75ef85523e338835433ad6ec6a1a078093c1328d8b9f7e248ce4a83bd0d003950e2217ea067c4e41a048dacdb1a35a0f78ef454d8ecc85c9d6f6d0d8a705cbec58fffc84793d9c3b76d853ecc2385caa063631ed946369e1f47b9c0c3d1d2ac931df1a5180ce3472668a72aeb990da222a0a15ffb96e932adb7d2b7360eca91f12d89aec1c957921e128749a2448a7a8e6ba0ab709448b0a0d98fd7e2d46f361ba10bba07f3664f3c4ff49dd909ce2940e78980a0746e1c79afcc4dcd0f96c3feb8ea3088ab53811b75dfbc08d6b6fc4f7fdde23ba0489ae63fa947006a7d4abd060567724236361df336b089d829399226f38ab722a0878fffa64732f90ad4b404cdf281164f7c3aa226b5dccbfce6ee341ac86cc83780"));
            vector::push_back(&mut non_zero_account_proof, hb(b"f851808080808080a0649d1b7e708cb13213bfe0858d554060a2e30c42d5dcb6a6843382e8e8dcb5f18080a0263da4d218b945dd69118a65e93f4f4425b8e49e6fee706c4f84f0728cb451ff80808080808080"));
            vector::push_back(&mut non_zero_account_proof, hb(b"f8709d20194830520789b05a013321e91eea8f4e3f60f4c00bf073bd94c1a864b850f84e820899880470de4df8200000a08ca3995950f1fc20246582dffab511b23061b51c08b9aff386fcb75c6ea1a52ca0461e17b7ae561793f22843985fc6866a3395c1fcee8ebf2d7ed5f293aec1b473"));


            // ---- create oracles via test-only factories (no direct struct packing) ----
            (state_admin, state_oracle) = state_root_registry::new_for_testing(ctx);
            (tx_admin, tx_oracle) = condition_tx_executor::new_for_testing(ctx);
            mpt_proof_verifier = mpt_proof_verifier::new_for_testing(ctx);

            // ---- submit state root ----
            let mut list_of_block_numbers = vector::empty<u64>();
            vector::push_back(&mut list_of_block_numbers, zero_block_number);
            vector::push_back(&mut list_of_block_numbers, non_zero_block_number);
            let mut list_of_state_roots = vector::empty<vector<u8>>();
            vector::push_back(&mut list_of_state_roots, zero_state_root);
            vector::push_back(&mut list_of_state_roots, non_zero_state_root);
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
            vector::push_back(&mut list_of_condition_account, zero_account);
            vector::push_back(&mut list_of_condition_account, non_zero_account);
            let mut list_of_condition_operator = vector::empty<u8>();
            vector::push_back(&mut list_of_condition_operator, 4);
            vector::push_back(&mut list_of_condition_operator, 1);
            let mut list_of_condition_value = vector::empty<u256>();
            vector::push_back(&mut list_of_condition_value, zero_expected_balance);
            vector::push_back(&mut list_of_condition_value, non_zero_expected_balance);
            // ---- submit command ----
            condition_tx_executor::submit_command_with_escrow(
                &tx_admin,
                &mut tx_oracle,
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
                zero_block_number,
                zero_account,
                zero_account_proof,
                zero_expected_nonce,
                zero_expected_balance,
                zero_expected_storage_root,
                zero_expected_code_hash,
                ctx
            );

            mpt_proof_verifier::verify_mpt_proof(
                &mut mpt_proof_verifier,
                &state_oracle,
                &mut tx_oracle,
                non_zero_block_number,
                non_zero_account,
                non_zero_account_proof,
                non_zero_expected_nonce,
                non_zero_expected_balance,
                non_zero_expected_storage_root,
                non_zero_expected_code_hash,
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
            condition_tx_executor::destroy_admin_for_testing(tx_admin);
            mpt_proof_verifier::destroy_verifier_for_testing(mpt_proof_verifier);
        };

        ts::end(scenario);
    }
}
