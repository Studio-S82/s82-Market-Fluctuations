let inventory   = {};
let activeName  = '';
let activeImage = '';
let activeLabel = '';

const Sakura = (function() {
    const canvas    = document.getElementById('sakura-canvas');
    const ctx       = canvas.getContext('2d');
    const container = document.querySelector('.container');

    let rafId    = null;  
    let running  = false;

    function resize() {
        canvas.width  = container.offsetWidth;
        canvas.height = container.offsetHeight;
    }
    resize();
    window.addEventListener('resize', resize);

    const COLORS = ['#fce4ec', '#f8bbd0', '#f48fb1', '#ffd6e7', '#ffe0eb'];

    function drawPetal(x, y, size, rotation, alpha, colorIdx) {
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(rotation);
        ctx.globalAlpha = alpha;
        ctx.fillStyle   = COLORS[colorIdx % COLORS.length];
        ctx.beginPath();
        for (let i = 0; i < 5; i++) {
            const angle = (i * Math.PI * 2) / 5 - Math.PI / 2;
            const cx1 = Math.cos(angle - 0.4) * size * 1.2;
            const cy1 = Math.sin(angle - 0.4) * size * 1.2;
            const cx2 = Math.cos(angle + 0.4) * size * 1.2;
            const cy2 = Math.sin(angle + 0.4) * size * 1.2;
            const ex  = Math.cos(angle) * size * 0.35;
            const ey  = Math.sin(angle) * size * 0.35;
            if (i === 0) ctx.moveTo(ex, ey);
            ctx.bezierCurveTo(cx1, cy1, cx2, cy2, ex, ey);
        }
        ctx.closePath();
        ctx.fill();
        ctx.restore();
    }

    const petals = Array.from({ length: 28 }, (_, i) => ({
        x:        Math.random() * 1400,
        y:        Math.random() * 600,
        size:     Math.random() * 6 + 4,
        speedY:   Math.random() * 0.8 + 0.3,
        speedX:   (Math.random() - 0.5) * 0.5,
        rotation: Math.random() * Math.PI * 2,
        rotSpeed: (Math.random() - 0.5) * 0.03,
        alpha:    Math.random() * 0.35 + 0.1,
        colorIdx: i % COLORS.length,
    }));

    function animate() {
        if (!running) return;
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        petals.forEach(p => {
            p.y        += p.speedY;
            p.x        += p.speedX + Math.sin(p.y * 0.012) * 0.4;
            p.rotation += p.rotSpeed;
            if (p.y > canvas.height + 20) { p.y = -20; p.x = Math.random() * canvas.width; }
            if (p.x < -20)                  p.x = canvas.width + 10;
            if (p.x > canvas.width + 20)    p.x = -10;
            drawPetal(p.x, p.y, p.size, p.rotation, p.alpha, p.colorIdx);
        });
        rafId = requestAnimationFrame(animate);
    }

    return {
        start() {
            if (running) return;
            running = true;
            rafId   = requestAnimationFrame(animate);
        },
        stop() {
            running = false;
            if (rafId) { cancelAnimationFrame(rafId); rafId = null; }
            ctx.clearRect(0, 0, canvas.width, canvas.height);
        }
    };
})();

function imgSrc(itemName, imageOverride) {
    if (imageOverride && imageOverride.startsWith('http')) return imageOverride;
    return `nui://ox_inventory/web/images/${itemName}.png`;
}

function setSelectedItem(name, image, label) {
    activeName  = name;
    activeImage = image;
    activeLabel = label;

    const imgRight = document.querySelector('.img-right');
    const nameEl   = document.getElementById('selected-name');
    const stockEl  = document.getElementById('stock-badge');

    if (imgRight) imgRight.src            = imgSrc(name, image);
    if (nameEl)   nameEl.textContent      = label || name;
    if (stockEl)  stockEl.textContent     = 'Tồn kho: ' + (inventory[name] || 0);

    document.querySelectorAll('.item').forEach(el => {
        el.classList.toggle('selected', el.getAttribute('data-name') === name);
    });
}

window.addEventListener('message', (e) => {
    const { type, data: msgData, item: msgItem, meta } = e.data;

 
    if (type === 'open') {
        inventory = e.data.inventory || {};

        const sellerCard = document.getElementById('seller-card');
        const priceCard  = document.getElementById('price-card');
        const grid       = document.getElementById('item-grid');

        grid.innerHTML = '';
        activeName = activeImage = activeLabel = '';

        const imgRight = document.querySelector('.img-right');
        if (imgRight) imgRight.src = '';
        document.getElementById('selected-name').textContent = '— Chưa chọn —';
        document.getElementById('stock-badge').textContent   = 'Tồn kho: 0';

        e.data.items.forEach(item => {
            const count = inventory[item.itemName] || 0;
            const div   = document.createElement('div');
            div.classList.add('item');
            div.setAttribute('data-name',  item.itemName);
            div.setAttribute('data-image', item.image || '');
            div.setAttribute('data-label', item.Label || item.itemName);
            div.innerHTML = `
                <img src="${imgSrc(item.itemName, item.image)}" alt="${item.Label}"
                     onerror="this.style.opacity='0.3'">
                <span class="item-name">${item.Label}</span>
                <span class="item-stock">x${count}</span>
            `;
            div.addEventListener('click', () => {
                setSelectedItem(item.itemName, item.image, item.Label);
            });
            grid.appendChild(div);
        });

        if (sellerCard) sellerCard.classList.add('active');
        if (priceCard)  priceCard.classList.add('active');
        Sakura.start();

       
        if (e.data.items.length > 0) {
            const first = e.data.items[0];
            setSelectedItem(first.itemName, first.image, first.Label);
        }
    }

    else if (type === 'close') {
        ['seller-card', 'price-card', 'popup-market'].forEach(id => {
            const el = document.getElementById(id);
            if (el) el.classList.remove('active');
        });
        activeName = activeImage = activeLabel = '';
        const input = document.getElementById('sell-input');
        if (input) input.value = '';
        Sakura.stop();
    }

    else if (type === 'set-price') {
        renderPriceList(e.data.data, 'price-list');
        renderPriceList(e.data.data, 'popup-list');
    }

    else if (type === 'update-price') {
        updatePriceRow(e.data.item, e.data.data, 'price-list');
        updatePriceRow(e.data.item, e.data.data, 'popup-list');
    }

    else if (type === 'show-price') {
        const popup = document.getElementById('popup-market');
        if (popup) popup.classList.add('active');
        Sakura.start();
    }
});

function renderPriceList(items, containerId) {
    const el = document.getElementById(containerId);
    if (!el) return;
    el.innerHTML = '';
    items.forEach(item => {
        const li = document.createElement('li');
        li.classList.add('item-price-' + item.itemName);
        li.innerHTML = buildPriceRow(item);
        el.appendChild(li);
    });
}

function buildPriceRow(item) {
    const arrow = item.Status === 'up' ? '↑' : item.Status === 'down' ? '↓' : '—';
    return `
        <img src="${imgSrc(item.itemName, item.image)}" alt="${item.Label}"
             onerror="this.style.opacity='0.3'">
        <span>${item.Label}</span>
        <span class="price ${item.Status}">
            $${item.Price.toLocaleString()} ${arrow}
        </span>
    `;
}

function updatePriceRow(itemName, item, containerId) {
    const el = document.getElementById(containerId);
    if (!el) return;
    const li = el.querySelector('.item-price-' + itemName);
    if (li) li.innerHTML = buildPriceRow(item);
}

document.getElementById('btn-sell').addEventListener('click', () => {
    if (!activeName) return;
    const input  = document.getElementById('sell-input');
    const amount = parseInt(input.value);
    if (!amount || amount <= 0) return;

    navigator.sendBeacon('https://s82chotroi/action', JSON.stringify({
        item:   activeName,
        amount: amount
    }));
    input.value = '';
});

document.getElementById('btn-sell-all').addEventListener('click', () => {
    if (!activeName) return;
    navigator.sendBeacon('https://s82chotroi/action-all', JSON.stringify({
        item: activeName
    }));
});

document.getElementById('popup-close').addEventListener('click', () => {
    const popup = document.getElementById('popup-market');
    if (popup) popup.classList.remove('active');
    Sakura.stop();
    navigator.sendBeacon('https://s82chotroi/close', JSON.stringify({}));
});

document.addEventListener('keyup', (e) => {
    if (e.code === 'Escape') {
        navigator.sendBeacon('https://s82chotroi/close', JSON.stringify({}));
    }
});
