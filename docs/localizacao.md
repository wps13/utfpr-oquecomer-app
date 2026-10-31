# Localização

`LocationService` obtém a posição atual somente durante o uso do aplicativo e
converte suas coordenadas para `Cidade, Estado`. A implementação
`DeviceLocationService` é registrada no `MultiProvider` e pode ser injetada em
qualquer ViewModel:

```dart
final service = context.read<LocationService>();
final local = await service.getCurrentLocation();
```

O serviço lança falhas de domínio distintas:

- `LocationPermissionDeniedFailure`: permissão recusada ou bloqueada;
- `LocationServiceDisabledFailure`: GPS/serviço de localização desligado;
- `GeocodingFailure`: nenhum endereço utilizável foi retornado;
- `LocationTimeoutFailure`: aquisição ou geocodificação excedeu o limite;
- `LocationUnavailableFailure`: falha inesperada do plugin.

Todos esses casos devem ser tratados pela ViewModel sem deixar a exceção chegar
à interface sem tratamento.

O serviço usa o geocodificador nativo por meio dos pacotes `geolocator` e
`geocoding`. O aplicativo não exibe mapas e, por isso, não requer Google Maps
SDK, API key ou configuração no Google Cloud. A localização obtida é usada
somente como contexto de cidade e estado no prompt.

A geocodificação reversa depende do backend disponível no aparelho e de conexão
com a internet; em aparelhos sem esse backend, como alguns modelos Huawei, ela
pode falhar ou retornar nenhum resultado. Nesses casos, o serviço lança
`GeocodingFailure`. A cidade usa `locality` e, quando esse campo não está
disponível, `subAdministrativeArea` como fallback. O estado usa
`administrativeArea` e permanece com o nome retornado pela plataforma, sem
conversão para sigla.

Após a primeira resolução bem-sucedida, o resultado é mantido em cache durante
a vida do serviço. Requisições simultâneas compartilham a mesma consulta, e
falhas não são cacheadas, permitindo uma nova tentativa posterior. Isso evita
chamadas repetidas ao `CLGeocoder`, que possui limite de taxa no iOS.
