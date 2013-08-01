# -*- encoding: utf-8 -*-

begin
  require 'rghost'
rescue LoadError
  require 'rubygems' unless ENV['NO_RUBYGEMS']
  gem 'rghost'
  require 'rghost'
end

begin
  require 'rghost_barcode'
rescue LoadError
  require 'rubygems' unless ENV['NO_RUBYGEMS']
  gem 'rghost_barcode'
  require 'rghost_barcode'
end

module Brcobranca
  module Boleto
    module Template
      # Templates para usar com Rghost
      module Rghost
        extend self
        include RGhost unless self.include?(RGhost)
        RGhost::Config::GS[:external_encoding] = Brcobranca.configuration.external_encoding

        # Gera o boleto em usando o formato desejado [:pdf, :jpg, :tif, :png, :ps, :laserjet, ... etc]
        #
        # @return [Stream]
        # @see http://wiki.github.com/shairontoledo/rghost/supported-devices-drivers-and-formats Veja mais formatos na documentação do rghost.
        # @see Rghost#modelo_generico Recebe os mesmos parâmetros do Rghost#modelo_generico.
        def to(formato, options={})
          modelo_generico(self, options.merge!({:formato => formato}))
        end

        # Gera o boleto em usando o formato desejado [:pdf, :jpg, :tif, :png, :ps, :laserjet, ... etc]
        #
        # @return [Stream]
        # @see http://wiki.github.com/shairontoledo/rghost/supported-devices-drivers-and-formats Veja mais formatos na documentação do rghost.
        # @see Rghost#modelo_generico Recebe os mesmos parâmetros do Rghost#modelo_generico.
        def lote(boletos, options={})
          modelo_generico_multipage(boletos, options)
        end

        #  Cria o métodos dinâmicos (to_pdf, to_gif e etc) com todos os fomátos válidos.
        #
        # @return [Stream]
        # @see Rghost#modelo_generico Recebe os mesmos parâmetros do Rghost#modelo_generico.
        # @example
        #  @boleto.to_pdf #=> boleto gerado no formato pdf
        def method_missing(m, *args)
          method = m.to_s
          if method.start_with?("to_")
            modelo_generico(self, (args.first || {}).merge!({:formato => method[3..-1]}))
          else
            super
          end
        end

        private

        # Retorna um stream pronto para gravação em arquivo.
        #
        # @return [Stream]
        # @param [Boleto] Instância de uma classe de boleto.
        # @param [Hash] options Opção para a criação do boleto.
        # @option options [Symbol] :resolucao Resolução em pixels.
        # @option options [Symbol] :formato Formato desejado [:pdf, :jpg, :tif, :png, :ps, :laserjet, ... etc]
        def modelo_generico(boleto, options={})
          doc=Document.new :paper => :A4 # 210x297

          template_path = File.join(File.dirname(__FILE__),'..','..','arquivos','templates','modelo_generico.eps')

          raise "Não foi possível encontrar o template. Verifique o caminho" unless File.exist?(template_path)

          modelo_generico_template(doc, boleto, template_path)
          modelo_generico_cabecalho(doc, boleto)
          modelo_generico_rodape(doc, boleto)

          #Gerando codigo de barra com rghost_barcode
          doc.barcode_interleaved2of5(boleto.codigo_barras, :width => '10.3 cm', :height => '1.3 cm', :x => '0.7 cm', :y => '4.4 cm' ) if boleto.codigo_barras

          # Gerando stream
          formato = (options.delete(:formato) || Brcobranca.configuration.formato)
          resolucao = (options.delete(:resolucao) || Brcobranca.configuration.resolucao)
          doc.render_stream(formato.to_sym, :resolution => resolucao)
        end

        # Retorna um stream para multiplos boletos pronto para gravação em arquivo.
        #
        # @return [Stream]
        # @param [Array] Instâncias de classes de boleto.
        # @param [Hash] options Opção para a criação do boleto.
        # @option options [Symbol] :resolucao Resolução em pixels.
        # @option options [Symbol] :formato Formato desejado [:pdf, :jpg, :tif, :png, :ps, :laserjet, ... etc]
        def modelo_generico_multipage(boletos, options={})
          doc=Document.new :paper => :A4 # 210x297

          template_path = File.join(File.dirname(__FILE__),'..','..','arquivos','templates','modelo_generico.eps')

          raise "Não foi possível encontrar o template. Verifique o caminho" unless File.exist?(template_path)

          boletos.each_with_index do |boleto, index|

            modelo_generico_template(doc, boleto, template_path)
            modelo_generico_cabecalho(doc, boleto)
            modelo_generico_rodape(doc, boleto)

            #Gerando codigo de barra com rghost_barcode
            doc.barcode_interleaved2of5(boleto.codigo_barras, :width => '10.3 cm', :height => '1.3 cm', :x => '0.7 cm', :y => '5.8 cm' ) if boleto.codigo_barras
            #Cria nova página se não for o último boleto
            doc.next_page unless index == boletos.length-1

          end
          # Gerando stream
          formato = (options.delete(:formato) || Brcobranca.configuration.formato)
          resolucao = (options.delete(:resolucao) || Brcobranca.configuration.resolucao)
          doc.render_stream(formato.to_sym, :resolution => resolucao)
        end

        # Define o template a ser usado no boleto
        def modelo_generico_template(doc, boleto, template_path)
          doc.define_template(:template, template_path, :x => '0.3 cm', :y => "0 cm")
          doc.use_template :template

          doc.define_tags do
            tag :grande, :size => 13
          end
        end

        # Monta o cabeçalho do layout do boleto
        def modelo_generico_cabecalho(doc, boleto)
          #INICIO Primeira parte do BOLETO
          doc.moveto :x => '0.5 cm', :y => '29 cm'
          doc.show "BOLETO ORIGINAL - Detalhamento (Vencimento #{boleto.venc_original.to_s_br} e Nosso Número #{boleto.numero_documento})", :with => :bold
          doc.moveto :x => '3.5 cm', :y => '28.6 cm'
          doc.show "#{boleto.sacado} - (#{boleto.cedente})"

          doc.moveto :x => '3.5 cm', :y => '28.1 cm'
          if boleto.acordo.nil?
            doc.show "COMPOSIÇÃO DA ARRECADAÇÃO - Compet.: #{boleto.mes_referencia} - Valor Total Original: R$ #{boleto.valor_original.to_currency}", :with => :bold
          else
            doc.show "COMPOSIÇÃO DA ARRECADAÇÃO - Compet.: #{boleto.mes_referencia} - Acordo: #{boleto.acordo} Valor Total Original: R$ #{boleto.valor_original.to_currency}", :with => :bold
          end

          #LOGOTIPO da EMPRESA
          doc.image(boleto.logoempresa, :x => '0.7 cm', :y => '26.1 cm', :zoom => 80)  
          #Composição da arrecadação

          yy = 27.7
          boleto.composicao.each do |lanc|
            doc.moveto :x => '3.7 cm', :y => yy.to_s + ' cm'
            doc.show lanc
            yy = yy - 0.3
          end

          #Unidades vinculadas
          doc.moveto :x => '16.7 cm', :y => '27.7 cm'
          doc.show "Unidades vinculadas:", :with => :bold
          doc.text_area "#{boleto.unidades_vinculadas}", :width => '4 cm', :x => '16.7 cm', :y => '27.4 cm'

          # LOGOTIPO do BANCO
          doc.moveto :x => '0.5 cm' , :y => '24.9 cm'
          doc.show "BOLETO EXPRESSO (2 VIA de BOLETO gerado pelo site www.bersi.com.br).", :with => :bold
          doc.moveto :x => '0.5 cm' , :y => '24.5 cm'
          doc.show "Caso a geração da 2 via seja feita após o vencimento original, o novo boleto será corrigido com os acréscimos legais."
          doc.moveto :x => '0.5 cm' , :y => '24.1 cm'
          doc.show "Em caso de dúvidas ou esclarecimentos adicionais contatar a BERSI ADMINISTRADORA."
          doc.image(boleto.logotipo, :x => '0.5 cm', :y => '22.6 cm', :zoom => 80)
          # Dados
          doc.moveto :x => '5.2 cm' , :y => '22.6 cm'
          doc.show "#{boleto.banco}-#{boleto.banco_dv}", :tag => :grande
          doc.moveto :x => '7.5 cm' , :y => '22.6 cm'
          doc.show boleto.codigo_barras.linha_digitavel, :tag => :grande

          doc.moveto :x => '0.7 cm' , :y => '21.85 cm'
          doc.show boleto.cedente
          doc.moveto :x => '11 cm' , :y => '21.85 cm'
          doc.show boleto.agencia_conta_boleto
          doc.moveto :x => '14.2 cm' , :y => '21.85 cm'
          doc.show boleto.especie
          doc.moveto :x => '15.7 cm' , :y => '21.85 cm'
          doc.show boleto.quantidade
          doc.moveto :x => '16.5 cm' , :y => '21.85 cm'
          doc.show boleto.nosso_numero_boleto

          doc.moveto :x => '0.7 cm' , :y => '21.0 cm'
          doc.show boleto.numero_documento
          doc.moveto :x => '7 cm' , :y => '21.0 cm'
          doc.show "#{boleto.documento_cedente.formata_documento}"
          doc.moveto :x => '12 cm' , :y => '21.0 cm'
          doc.show boleto.data_vencimento.to_s_br
          doc.moveto :x => '16.5 cm' , :y => '21.0 cm'
          doc.show boleto.valor_documento.to_currency

          doc.moveto :x => '1.4 cm' , :y => '19.75 cm'
          doc.show "#{boleto.sacado}"

          #doc.moveto :x => '1.4 cm' , :y => '19.35 cm'
          #doc.show "#{boleto.sacado_endereco}"
          #FIM Primeira parte do BOLETO
        end

        # Monta o corpo e rodapé do layout do boleto
        def modelo_generico_rodape(doc, boleto)
          #INICIO Segunda parte do BOLETO BB
          # LOGOTIPO do BANCO
          doc.image(boleto.logotipo, :x => '0.5 cm', :y => '15.6 cm', :zoom => 80)
          doc.moveto :x => '5.2 cm' , :y => '15.6 cm'
          doc.show "#{boleto.banco}-#{boleto.banco_dv}", :tag => :grande
          doc.moveto :x => '7.5 cm' , :y => '15.6 cm'
          doc.show boleto.codigo_barras.linha_digitavel, :tag => :grande

          doc.moveto :x => '0.7 cm' , :y => '14.8 cm'
          doc.show boleto.local_pagamento
          doc.moveto :x => '16.5 cm' , :y => '14.8 cm'
          doc.show boleto.data_vencimento.to_s_br if boleto.data_vencimento

          doc.moveto :x => '0.7 cm' , :y => '14 cm'
          doc.show boleto.cedente
          doc.moveto :x => '16.5 cm' , :y => '14 cm'
          doc.show boleto.agencia_conta_boleto

          doc.moveto :x => '0.7 cm' , :y => '13.10 cm'
          doc.show boleto.data_documento.to_s_br if boleto.data_documento
          doc.moveto :x => '4.2 cm' , :y => '13.10 cm'
          doc.show boleto.numero_documento
          doc.moveto :x => '10 cm' , :y => '13.10 cm'
          doc.show boleto.especie_documento
          doc.moveto :x => '11.7 cm' , :y => '13.10 cm'
          doc.show boleto.aceite
          doc.moveto :x => '13 cm' , :y => '13.10 cm'
          doc.show boleto.data_processamento.to_s_br if boleto.data_processamento
          doc.moveto :x => '16.5 cm' , :y => '13.10 cm'
          doc.show boleto.nosso_numero_boleto

          doc.moveto :x => '4.4 cm' , :y => '12.30 cm'
          doc.show boleto.carteira
          doc.moveto :x => '6.4 cm' , :y => '12.30 cm'
          doc.show boleto.especie
          doc.moveto :x => '8 cm' , :y => '12.30 cm'
          doc.show boleto.quantidade
          doc.moveto :x => '11 cm' , :y => '12.30 cm'
          doc.show boleto.valor.to_currency
          doc.moveto :x => '16.5 cm' , :y => '12.30 cm'
          doc.show boleto.valor_documento.to_currency

          doc.moveto :x => '0.7 cm' , :y => '11.4 cm'
          doc.show boleto.instrucao1
          doc.moveto :x => '0.7 cm' , :y => '11.0 cm'
          doc.show boleto.instrucao2
          doc.moveto :x => '0.7 cm' , :y => '10.6 cm'
          doc.show boleto.instrucao3
          doc.moveto :x => '0.7 cm' , :y => '10.2 cm'
          doc.show boleto.instrucao4
          doc.moveto :x => '0.7 cm' , :y => '9.8 cm'
          doc.show boleto.instrucao5
          doc.moveto :x => '0.7 cm' , :y => '9.4 cm'
          doc.show boleto.instrucao6

          doc.moveto :x => '1.2 cm' , :y => '7.6 cm'
          doc.show "#{boleto.sacado}" if boleto.sacado
          #doc.moveto :x => '1.2 cm' , :y => '7.2 cm'
          #doc.show "#{boleto.sacado_endereco}"
          #FIM Segunda parte do BOLETO
        end

      end #Base
    end
  end
end

