# Armazenamento local de favoritos

O app escolhe o `hive_ce` para persistir favoritos localmente. O Hive permite
armazenar estruturas flexíveis (neste caso, mapas que representam o contrato
compartilhado da API) sem exigir um banco relacional ou migrações complexas.
Além disso, as operações são locais e de alta velocidade, uma característica
adequada mesmo quando o app precisar executar muitas leituras e escritas.

O pacote utilizado é [`hive_ce`](https://pub.dev/packages/hive_ce), com
`hive_ce_flutter` para inicialização no caminho de dados de cada plataforma.
O box `favorites` armazena uma entrada por ID da receita. O modelo
O modelo compartilhado `Recipe` preserva os campos da API (`receita`, `ingredientes`,
`modo_preparo`, `link_imagem`, `tipo`, `created_at` e `IngredientesBase`) e
acrescenta `origem` e `favoritada_em`, permitindo listar receitas do catálogo e
geradas por IA juntas.

O acesso é feito exclusivamente por `HiveFavoritesRepository`. Falhas de
leitura, escrita, exclusão ou verificação são reportadas ao Crashlytics por
meio de `ErrorReporter` e depois propagadas para a ViewModel, que apresenta o
estado de erro à interface.
