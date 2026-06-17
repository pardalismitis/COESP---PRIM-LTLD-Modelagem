# Changelog
## v1.0.1 (2026-06-16)

### Adicionado
*	Inclusão da coluna “fonte_habitat” na planilha de ocorrências, por meio do script “classes_habitat_especie”. Os valores dessa coluna indicam se os dados utilizados serão as classes do MapBiomas ou as informações do mapa de potencialidade de cavernas, de acordo com o habitat da espécie extraído da planilha geral do SALVE.
* Inclusão do raster de potencialidade de cavernas (caves_potencial_brasil_1km.tif) ao protocolo de modelagem.
*	Implementação da distinção entre habitats modelados por MapBiomas e habitats cavernícolas na função kernel_ponderado(), para permitir a escolha conforme a espécie na modelagem.

  ### Modificado ou corrigido
  
*	Para espécies cavernícolas, o kernel passa a utilizar o raster de potencialidade de cavernas em vez do MapBiomas.
*	Para as demais espécies, o kernel utiliza a classe do MapBiomas que representa o habitat. O valor da classe é incluído na planilha de ocorrências, por meio do script “classes_habitat_especie”.
*	Regra de reclassificação do raster de cavernas, considerando as classes 3 (alto) e 4 (muito alto) como habitat adequado. Esse processo evita mudanças muito longas e confusas na função kernel_ponderado().
*	Modificado o nome do script 02 no repositório. "02_classes_mapbiomas.R" passa a se chamar "02_classes_habitat_espécies.R".
* Melhorias e limpezas gerais nos códigos.

## v1.0.0 (2026-06-10)

* Os scripts base usados foram os disponibilizados na pasta Modelagem_PRIM no dia 22/05/2026 e atualizados no intervalo entre essa data e 09/06/2026.

### Adicionado

* Inclusão do objeto bg_env no código dos protocolos de modelagem (geração de pseudoausências para alguns algoritmos, script 03).
* Inclusão de novas famílias para o protocolo "aquáticas" (script 01).
* Criação de uma versão individual do workflow para testes de espécies específicas (script 03).

### Modificado ou corrigido

* Corrigida a parte do loop principal com a inclusão das peseudoausências (bg_env, script 03).
* Reorganização da estrutura dos scripts (01, 02, 03).
* Atualização do fluxo de entrada e saída de dados (01, 02, 03).
* Melhorias gerais de desempenho e manutenção do código (01, 02, 03).

---
