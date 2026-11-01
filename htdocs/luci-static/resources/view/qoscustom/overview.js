'use strict';
'require view';
'require form';
'require fs';
'require uci';
'require ui';

function showStats(wanIf, lanIf) {
	var rows = [];

	return Promise.all([
		fs.exec('/usr/bin/tc', [ '-s', 'qdisc', 'show', 'dev', wanIf ]).catch(function() { return { stdout: '' }; }),
		fs.exec('/usr/bin/tc', [ '-s', 'class', 'show', 'dev', lanIf ]).catch(function() { return { stdout: '' }; }),
		fs.exec('/usr/bin/tc', [ '-s', 'qdisc', 'show', 'dev', lanIf ]).catch(function() { return { stdout: '' }; })
	]).then(function(res) {
		rows.push(E('h3', {}, [ '上行整形（', wanIf, '）' ]));
		rows.push(E('pre', { 'style': 'white-space:pre-wrap;font-size:12px;margin:0 0 1em 0' },
			(res[0] && res[0].stdout) ? res[0].stdout : '（无规则，QoS 可能未启用）'));

		rows.push(E('h3', {}, [ '下行整形（', lanIf, '）' ]));
		rows.push(E('pre', { 'style': 'white-space:pre-wrap;font-size:12px;margin:0 0 1em 0' },
			(res[2] && res[2].stdout) ? res[2].stdout : '（无规则）'));

		rows.push(E('h3', {}, [ '分类统计（内网 vs 外网）' ]));
		rows.push(E('pre', { 'style': 'white-space:pre-wrap;font-size:12px;margin:0' },
			(res[1] && res[1].stdout) ? res[1].stdout : '（无分类）'));

		var box = document.getElementById('qos-stats');
		if (box) {
			while (box.firstChild)
				box.removeChild(box.firstChild);
			for (var i = 0; i < rows.length; i++)
				box.appendChild(rows[i]);
		}
	});
}

return view.extend({
	load: function() {
		return uci.load('qoscustom');
	},

	render: function() {
		var m, s, o;
		var self = this;

		var wanIf = uci.get('qoscustom', 'settings', 'interface') || 'pppoe-wan';
		var lanIf = uci.get('qoscustom', 'settings', 'lan_iface') || 'br-lan';

		m = new form.Map('qoscustom', _('QoS 流量控制'),
			_('基于 CAKE 智能队列 + HTB 分类的自定义限速。修改数值后点“保存”，再点“应用并重启 QoS”生效。'));

		s = m.section(form.NamedSection, 'settings', 'settings', _('限速设置'));
		s.anonymous = true;

		o = s.option(form.Flag, 'enabled', _('启用 QoS'),
			_('关闭后不挂任何队列规则，等同于关闭 QoS'));
		o.rmempty = false;

		o = s.option(form.Value, 'uplink_mbit', _('上行带宽 (Mbit)'),
			_('填实际上行带宽的 95%，例如 100M 填 95'));
		o.datatype = 'uinteger';
		o.placeholder = '95';
		o.rmempty = false;

		o = s.option(form.Value, 'downlink_mbit', _('下行带宽 (Mbit)'),
			_('填实际下行带宽的 95%；开了“内网互传不限速”时，内网互传不受此限'));
		o.datatype = 'uinteger';
		o.placeholder = '1150';
		o.rmempty = false;

		o = s.option(form.Flag, 'lan_bypass', _('内网互传不限速'),
			_('开启后用 HTB 分类，源地址为本网段的流量走 10Gbit 通道，不参与外网限速'));
		o.default = '1';
		o.rmempty = false;

		o = s.option(form.Value, 'interface', _('上行接口'),
			_('PPPoE 拨号接口一般填 pppoe-wan'));
		o.placeholder = 'pppoe-wan';
		o.rmempty = false;

		return m.render().then(function(mapEl) {
			var btns = E('div', { 'class': 'cbi-page-actions' }, [
				E('button', {
					'class': 'cbi-button cbi-button-apply',
					'click': ui.createHandlerFn(self, function() {
						return m.save().then(function() {
							return uci.apply();
						}).then(function() {
							/* 等 commit 落盘后再重启，否则脚本会读到旧值 */
							return new Promise(function(resolve) { setTimeout(resolve, 800); });
						}).then(function() {
							return fs.exec('/etc/init.d/qos-custom', [ 'restart' ]);
						}).then(function() {
							ui.addNotification(null, E('p', {}, _('配置已保存，QoS 已按新参数重启')), 'info');
							return showStats(wanIf, lanIf);
						}).catch(function(e) {
							ui.addNotification(null, E('p', {}, _('保存或重启失败：') + e), 'danger');
						});
					})
				}, [ _('保存并应用 QoS') ]),
				E('button', {
					'class': 'cbi-button cbi-button-action',
					'click': ui.createHandlerFn(self, function() {
						return showStats(wanIf, lanIf);
					})
				}, [ _('刷新状态') ])
			]);

			var statsBox = E('div', { 'id': 'qos-stats', 'class': 'cbi-section' });

			setTimeout(function() { showStats(wanIf, lanIf); }, 100);

			return E('div', {}, [ mapEl, btns, statsBox ]);
		});
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
